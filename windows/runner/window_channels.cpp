// Должно быть ПЕРЕД любыми include, иначе windows.h определит макросы min/max
// и сломает std::min / std::max
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "window_channels.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <commctrl.h>
#include <dwmapi.h>
#include <objidl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

// gdiplus.h требует min/max, а NOMINMAX их убирает
namespace Gdiplus {
using std::max;
using std::min;
}  // namespace Gdiplus
#include <gdiplus.h>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using MethodCall = flutter::MethodCall<EncodableValue>;
using ResultPtr = std::shared_ptr<flutter::MethodResult<EncodableValue>>;
using Channel = flutter::MethodChannel<EncodableValue>;

// Рамка окна: origin в левом верхнем углу (в отличие от macOS, где Y снизу)
struct Frame {
  double x, y, w, h;
};

std::optional<double> GetNum(const EncodableMap& m, const char* key) {
  auto it = m.find(EncodableValue(std::string(key)));
  if (it == m.end()) return std::nullopt;
  if (auto d = std::get_if<double>(&it->second)) return *d;
  if (auto i = std::get_if<int32_t>(&it->second)) return static_cast<double>(*i);
  if (auto l = std::get_if<int64_t>(&it->second)) return static_cast<double>(*l);
  return std::nullopt;
}

std::optional<std::string> GetStr(const EncodableMap& m, const char* key) {
  auto it = m.find(EncodableValue(std::string(key)));
  if (it == m.end()) return std::nullopt;
  if (auto s = std::get_if<std::string>(&it->second)) return *s;
  return std::nullopt;
}

// ---------------------------------------------------------------------------
// Blur / прозрачность / стиль окна
// ---------------------------------------------------------------------------

struct ACCENT_POLICY {
  int AccentState;
  int AccentFlags;
  unsigned int GradientColor;  // ABGR
  int AnimationId;
};
struct WINDOWCOMPOSITIONATTRIBDATA {
  int Attrib;
  void* pvData;
  SIZE_T cbData;
};
using SetWindowCompositionAttributeFn =
    BOOL(WINAPI*)(HWND, WINDOWCOMPOSITIONATTRIBDATA*);

// Аналог NSVisualEffectView.
// Win11 22H2+: системный Acrylic (DWMWA_SYSTEMBACKDROP_TYPE) - не лагает при
// перетаскивании. Иначе - обычный blur-behind (Acrylic через
// SetWindowCompositionAttribute сильно тормозит при перемещении окна).
void SetBlur(HWND hwnd, bool enable) {
  static auto fn = reinterpret_cast<SetWindowCompositionAttributeFn>(
      GetProcAddress(GetModuleHandleW(L"user32.dll"),
                     "SetWindowCompositionAttribute"));

  auto setAccent = [&](int state) {
    if (!fn) return;
    ACCENT_POLICY policy{};
    policy.AccentState = state;
    policy.AccentFlags = 2;
    policy.GradientColor = 0x66000000;
    WINDOWCOMPOSITIONATTRIBDATA data{19 /*WCA_ACCENT_POLICY*/, &policy,
                                     sizeof(policy)};
    fn(hwnd, &data);
  };

  int dark = 1;  // тёмная тема для материала
  DwmSetWindowAttribute(hwnd, 20 /*DWMWA_USE_IMMERSIVE_DARK_MODE*/, &dark,
                        sizeof(dark));

  // 3 = DWMSBT_TRANSIENTWINDOW (acrylic), 1 = DWMSBT_NONE
  int backdrop = enable ? 3 : 1;
  HRESULT hr = DwmSetWindowAttribute(hwnd, 38 /*DWMWA_SYSTEMBACKDROP_TYPE*/,
                                     &backdrop, sizeof(backdrop));
  if (SUCCEEDED(hr)) {
    setAccent(0);  // не смешиваем с accent-политикой
    return;
  }
  setAccent(enable ? 3 /*ENABLE_BLURBEHIND*/ : 0 /*DISABLED*/);
}

// Радиус запасного скругления (Win10) в логических пикселях
constexpr double kCornerRadiusDip = 16.0;

bool g_useRegion = false;  // true только если нужно скруглять вручную (Win10)
bool g_regionSet = false;

// Запасной вариант для Win10: обрезка по скруглённой области.
// Вызывается при ЛЮБОМ изменении размера окна (см. подкласс ниже).
void UpdateRegion(HWND hwnd) {
  if (!g_useRegion) {
    if (g_regionSet) {
      SetWindowRgn(hwnd, nullptr, TRUE);
      g_regionSet = false;
    }
    return;
  }
  RECT r;
  if (!GetWindowRect(hwnd, &r)) return;
  int w = r.right - r.left;
  int h = r.bottom - r.top;
  double s = GetDpiForWindow(hwnd) / 96.0;
  int d = static_cast<int>(std::lround(kCornerRadiusDip * s * 2));
  SetWindowRgn(hwnd, CreateRoundRectRgn(0, 0, w + 1, h + 1, d, d), TRUE);
  g_regionSet = true;
}

// round = true  -> обычный режим: скруглённые углы
// round = false -> island: углов нет (форму рисует Flutter, окно прозрачное)
void SetRoundedCorners(HWND hwnd, bool round) {
  // DWM-скругление для окон без рамки (WS_POPUP) ненадёжно -> отключаем и
  // всегда скругляем сами через регион (работает на Win10 и Win11).
  int pref = 1;  // DWMWCP_DONOTROUND
  DwmSetWindowAttribute(hwnd, 33 /*DWMWA_WINDOW_CORNER_PREFERENCE*/, &pref,
                        sizeof(pref));
  g_useRegion = round;  // island (round=false) -> без скругления
  UpdateRegion(hwnd);
}

// Ловим любое изменение размера окна (в т.ч. из Dart/других плагинов),
// чтобы область не «застывала» на старом размере.
LRESULT CALLBACK RegionSubclassProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp,
                                    UINT_PTR, DWORD_PTR) {
  if (msg == WM_NCDESTROY) {
    RemoveWindowSubclass(hwnd, RegionSubclassProc, 1);
  }
  LRESULT res = DefSubclassProc(hwnd, msg, wp, lp);
  if (msg == WM_SIZE || msg == WM_DPICHANGED) {
    if (g_useRegion) UpdateRegion(hwnd);
  }
  return res;
}

void ApplyBaseWindowStyle(HWND hwnd) {
  // styleMask = [.titled, .fullSizeContentView] + скрытые кнопки + прозрачный titlebar
  // -> окно без рамки и заголовка
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  style &= ~static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW);
  style |= WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
  SetWindowLongPtr(hwnd, GWL_STYLE, style);

  // collectionBehavior (.ignoresCycle) -> не показывать в таскбаре и Alt+Tab
  LONG_PTR ex = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  ex &= ~static_cast<LONG_PTR>(WS_EX_APPWINDOW);
  ex |= WS_EX_TOOLWINDOW;
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex);

  // isOpaque = false, backgroundColor = .clear
  MARGINS margins{-1, -1, -1, -1};
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  // hasShadow = false: убираем рамку/обводку Win11
  unsigned int borderNone = 0xFFFFFFFE;  // DWMWA_COLOR_NONE
  DwmSetWindowAttribute(hwnd, 34 /*DWMWA_BORDER_COLOR*/, &borderNone,
                        sizeof(borderNone));
  SetRoundedCorners(hwnd, true);

  // level = .statusBar -> поверх всех окон
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  SetBlur(hwnd, true);
}

// Аналог makeKeyAndOrderFront + orderFrontRegardless.
// Windows запрещает «чужому» процессу красть фокус (foreground lock), поэтому
// временно присоединяем наш поток ввода к потоку активного окна.
void ForceToFront(HWND hwnd) {
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  HWND fg = GetForegroundWindow();
  DWORD cur = GetCurrentThreadId();
  DWORD fgThread = fg ? GetWindowThreadProcessId(fg, nullptr) : 0;
  bool attached = false;
  if (fgThread && fgThread != cur) {
    attached = AttachThreadInput(cur, fgThread, TRUE) != FALSE;
  }
  BringWindowToTop(hwnd);
  SetForegroundWindow(hwnd);
  if (attached) AttachThreadInput(cur, fgThread, FALSE);
}

constexpr UINT_PTR kInitialFrontTimerId = 0xA19;
int g_initialFrontTicks = 0;

// Раннер Flutter показывает окно после первого кадра, поэтому повторяем
// несколько раз в первые ~1.5 секунды.
void CALLBACK InitialFrontProc(HWND hwnd, UINT, UINT_PTR, DWORD) {
  ForceToFront(hwnd);
  if (++g_initialFrontTicks >= 4) KillTimer(hwnd, kInitialFrontTimerId);
}

// Windows не имеет уровня .statusBar: topmost-окна конкурируют между собой,
// а флаг мог быть выставлен, пока окно ещё было скрыто. Поэтому периодически
// подтверждаем HWND_TOPMOST (без активации и без смены позиции/размера).
constexpr UINT_PTR kKeepOnTopTimerId = 0xA18;
HWND g_hwnd = nullptr;

void CALLBACK KeepOnTopProc(HWND hwnd, UINT, UINT_PTR, DWORD) {
  if (!IsWindowVisible(hwnd)) return;
  if (GetAsyncKeyState(VK_LBUTTON) & 0x8000) return;  // не мешаем перетаскиванию
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

// ---------------------------------------------------------------------------
// Пружинная анимация (замена CASpringAnimation)
// ---------------------------------------------------------------------------

double SpringValue(double t, double m, double k, double c) {
  double w0 = std::sqrt(k / m);
  double z = c / (2.0 * std::sqrt(k * m));
  if (z < 0.9999) {  // недодемпфированная (с «отскоком»)
    double wd = w0 * std::sqrt(1.0 - z * z);
    return 1.0 - std::exp(-z * w0 * t) *
                     (std::cos(wd * t) + (z * w0 / wd) * std::sin(wd * t));
  }
  if (z <= 1.0001) {  // критическое демпфирование
    return 1.0 - std::exp(-w0 * t) * (1.0 + w0 * t);
  }
  double s = w0 * std::sqrt(z * z - 1.0);  // передемпфированная
  double r1 = -z * w0 + s;
  double r2 = -z * w0 - s;
  return 1.0 - (r2 * std::exp(r1 * t) - r1 * std::exp(r2 * t)) / (r2 - r1);
}

double SettlingDuration(double m, double k, double c) {
  double w0 = std::sqrt(k / m);
  double z = c / (2.0 * std::sqrt(k * m));
  double rate = z < 1.0 ? z * w0 : w0 * (z - std::sqrt(z * z - 1.0));
  if (rate <= 0) return 1.0;
  return std::clamp(std::log(1000.0) / rate, 0.05, 3.0);
}

class Animator {
 public:
  static Animator& Get() {
    static Animator a;
    return a;
  }

  void Start(HWND hwnd, Frame from, Frame to, double mass, double stiffness,
             double damping, std::function<void()> done) {
    if (active_) {  // прерываем предыдущую анимацию, но не оставляем Future висеть
      active_ = false;
      KillTimer(hwnd_, kTimerId);
      auto prev = std::move(done_);
      done_ = nullptr;
      if (prev) prev();
      if (active_) KillTimer(hwnd_, kTimerId), active_ = false;
    }
    hwnd_ = hwnd;
    from_ = from;
    to_ = to;
    m_ = mass;
    k_ = stiffness;
    c_ = damping;
    total_ = SettlingDuration(m_, k_, c_);
    done_ = std::move(done);
    start_ = std::chrono::steady_clock::now();
    active_ = true;
    SetTimer(hwnd_, kTimerId, 8, &Animator::TimerProc);
  }

  void Cancel() {
    if (active_) KillTimer(hwnd_, kTimerId);
    active_ = false;
    done_ = nullptr;
  }

 private:
  static constexpr UINT_PTR kTimerId = 0xA17;

  static void CALLBACK TimerProc(HWND, UINT, UINT_PTR, DWORD) {
    Get().Tick();
  }

  void Apply(const Frame& f) {
    SetWindowPos(hwnd_, nullptr, static_cast<int>(std::lround(f.x)),
                 static_cast<int>(std::lround(f.y)),
                 std::max(1, static_cast<int>(std::lround(f.w))),
                 std::max(1, static_cast<int>(std::lround(f.h))),
                 SWP_NOZORDER | SWP_NOACTIVATE);
    UpdateRegion(hwnd_);
  }

  void Tick() {
    if (!active_) return;
    double t = std::chrono::duration<double>(
                   std::chrono::steady_clock::now() - start_)
                   .count();
    if (t >= total_) {
      KillTimer(hwnd_, kTimerId);
      active_ = false;
      Apply(to_);
      auto done = std::move(done_);
      done_ = nullptr;
      if (done) done();  // может запустить следующую анимацию
      return;
    }
    double p = SpringValue(t, m_, k_, c_);
    Apply({from_.x + (to_.x - from_.x) * p, from_.y + (to_.y - from_.y) * p,
           from_.w + (to_.w - from_.w) * p, from_.h + (to_.h - from_.h) * p});
  }

  HWND hwnd_ = nullptr;
  Frame from_{}, to_{};
  double m_ = 1, k_ = 100, c_ = 10, total_ = 0.5;
  std::chrono::steady_clock::time_point start_;
  std::function<void()> done_;
  bool active_ = false;
};

// ---------------------------------------------------------------------------
// Иконка файла -> PNG
// ---------------------------------------------------------------------------

ULONG_PTR g_gdiplusToken = 0;

bool GetPngClsid(CLSID* clsid) {
  UINT num = 0, size = 0;
  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return false;
  std::vector<uint8_t> buf(size);
  auto* info = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buf.data());
  Gdiplus::GetImageEncoders(num, size, info);
  for (UINT i = 0; i < num; ++i) {
    if (wcscmp(info[i].MimeType, L"image/png") == 0) {
      *clsid = info[i].Clsid;
      return true;
    }
  }
  return false;
}

std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return L"";
  int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring w(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), w.data(), n);
  return w;
}

std::optional<std::vector<uint8_t>> GetIconPng(const std::wstring& path) {
  SHFILEINFOW sfi{};
  if (!SHGetFileInfoW(path.c_str(), 0, &sfi, sizeof(sfi),
                      SHGFI_ICON | SHGFI_LARGEICON)) {
    return std::nullopt;
  }
  HICON icon = sfi.hIcon;
  ICONINFO ii{};
  if (!GetIconInfo(icon, &ii)) {
    DestroyIcon(icon);
    return std::nullopt;
  }

  std::optional<std::vector<uint8_t>> out;
  BITMAP bm{};
  if (ii.hbmColor && GetObject(ii.hbmColor, sizeof(bm), &bm)) {
    int w = bm.bmWidth, h = bm.bmHeight;
    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;  // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    std::vector<uint32_t> px(static_cast<size_t>(w) * h);
    std::vector<uint32_t> mask(px.size());
    HDC dc = GetDC(nullptr);
    GetDIBits(dc, ii.hbmColor, 0, h, px.data(), &bi, DIB_RGB_COLORS);
    if (ii.hbmMask) {
      GetDIBits(dc, ii.hbmMask, 0, h, mask.data(), &bi, DIB_RGB_COLORS);
    }
    ReleaseDC(nullptr, dc);

    // Если у иконки нет альфа-канала — берём прозрачность из маски
    bool hasAlpha = false;
    for (auto p : px) {
      if ((p >> 24) != 0) {
        hasAlpha = true;
        break;
      }
    }
    if (!hasAlpha) {
      for (size_t i = 0; i < px.size(); ++i) {
        bool transparent = (mask[i] & 0x00FFFFFF) != 0;
        px[i] = (px[i] & 0x00FFFFFF) | (transparent ? 0x00000000 : 0xFF000000);
      }
    }

    CLSID png;
    if (GetPngClsid(&png)) {
      Gdiplus::Bitmap bmp(w, h, w * 4, PixelFormat32bppARGB,
                          reinterpret_cast<BYTE*>(px.data()));
      IStream* stream = nullptr;
      if (SUCCEEDED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) {
        if (bmp.Save(stream, &png, nullptr) == Gdiplus::Ok) {
          STATSTG st{};
          stream->Stat(&st, STATFLAG_NONAME);
          HGLOBAL hg = nullptr;
          if (SUCCEEDED(GetHGlobalFromStream(stream, &hg))) {
            void* data = GlobalLock(hg);
            if (data) {
              auto* b = static_cast<uint8_t*>(data);
              out = std::vector<uint8_t>(b, b + st.cbSize.QuadPart);
              GlobalUnlock(hg);
            }
          }
        }
        stream->Release();
      }
    }
  }

  if (ii.hbmColor) DeleteObject(ii.hbmColor);
  if (ii.hbmMask) DeleteObject(ii.hbmMask);
  DestroyIcon(icon);
  return out;
}

std::string WideToUtf8(const std::wstring& w) {
  if (w.empty()) return "";
  int n = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), nullptr, 0,
                              nullptr, nullptr);
  std::string s(n, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), s.data(), n, nullptr,
                      nullptr);
  return s;
}

// Возвращает путь, на который указывает ярлык .lnk (COM уже инициализирован
// раннером Flutter в main.cpp).
std::optional<std::wstring> ResolveShortcut(const std::wstring& lnkPath) {
  IShellLinkW* link = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&link)))) {
    return std::nullopt;
  }
  std::optional<std::wstring> out;
  IPersistFile* file = nullptr;
  if (SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&file)))) {
    if (SUCCEEDED(file->Load(lnkPath.c_str(), STGM_READ))) {
      link->Resolve(nullptr, SLR_NO_UI | SLR_NOSEARCH);
      wchar_t target[MAX_PATH] = {0};
      if (SUCCEEDED(link->GetPath(target, MAX_PATH, nullptr, 0)) &&
          target[0] != L'\0') {
        out = std::wstring(target);
      }
    }
    file->Release();
  }
  link->Release();
  return out;
}

// ---------------------------------------------------------------------------
// Контроллер окна (аналог методов MainFlutterWindow)
// ---------------------------------------------------------------------------

class WindowController {
 public:
  explicit WindowController(HWND hwnd) : hwnd_(hwnd) {}

  bool IsMouseInside() {
    POINT p;
    RECT r;
    if (!GetCursorPos(&p) || !GetWindowRect(hwnd_, &r)) return false;
    return PtInRect(&r, p) != FALSE;
  }

  void AnimateResize(double width, double height, double duration,
                     std::function<void()> completion) {
    double s = Scale();
    width *= s;
    height *= s;
    if (duration <= 0) duration = 0.3;

    Frame old = GetFrame();
    if (isIsland_) {
      if (!anchorX_) anchorX_ = old.x + old.w / 2;
      if (!anchorY_) anchorY_ = old.y;  // верхний край остаётся на месте
    }
    double cx = isIsland_ ? *anchorX_ : old.x + old.w / 2;
    double newY = isIsland_ ? *anchorY_ : old.y + old.h / 2 - height / 2;

    Frame nf{cx - width / 2, newY, width, height};
    RECT work = WorkArea();
    nf.x = std::max<double>(work.left,
                            std::min<double>(nf.x, work.right - width));

    SpringAnimate(nf, 0.8, 300 / duration, 30 / duration, std::move(completion));
  }

  void MoveToNotch(double width, double height, double wIsland, double hIsland,
                   std::function<void()> completion) {
    double s = Scale();
    width *= s;
    height *= s;
    wIsland *= s;
    hIsland *= s;
    RECT screen = MonitorRect();
    double sw = screen.right - screen.left;

    if (isIsland_) {
      isIsland_ = false;
      anchorX_.reset();
      anchorY_.reset();
      RestoreWindow(width, height, std::move(completion));
      oldFrame_.reset();
      return;
    }
    isIsland_ = true;

    if (!oldFrame_) {
      Frame cur = GetFrame();
      Frame nf{cur.x + cur.w / 2 - width / 2, cur.y + cur.h / 2 - height / 2,
               width, height};
      RECT work = WorkArea();
      nf.x = std::max<double>(work.left,
                              std::min<double>(nf.x, work.right - width));
      nf.y = std::max<double>(work.top,
                              std::min<double>(nf.y, work.bottom - height));
      oldFrame_ = nf;
    }

    SetRoundedCorners(hwnd_, false);  // borderless
    Frame pill{screen.left + (sw - 160 * s) / 2.0, (double)screen.top, 160 * s,
               20 * s};
    SpringAnimate(pill, 1, 220, 25, [=]() {
      SetBlur(hwnd_, false);  // убираем blurView
      Frame expand{screen.left + (sw - wIsland) / 2.0, (double)screen.top,
                   wIsland, hIsland};
      SpringAnimate(expand, 1, 150, 15, completion);
    });
  }

 private:
  double Scale() { return GetDpiForWindow(hwnd_) / 96.0; }

  Frame GetFrame() {
    RECT r;
    GetWindowRect(hwnd_, &r);
    return {(double)r.left, (double)r.top, (double)(r.right - r.left),
            (double)(r.bottom - r.top)};
  }

  RECT MonitorRect() {
    MONITORINFO mi{sizeof(mi)};
    GetMonitorInfo(MonitorFromWindow(hwnd_, MONITOR_DEFAULTTONEAREST), &mi);
    return mi.rcMonitor;
  }

  RECT WorkArea() {
    MONITORINFO mi{sizeof(mi)};
    GetMonitorInfo(MonitorFromWindow(hwnd_, MONITOR_DEFAULTTONEAREST), &mi);
    return mi.rcWork;
  }

  void SpringAnimate(Frame to, double mass, double stiffness, double damping,
                     std::function<void()> completion) {
    Animator::Get().Start(hwnd_, GetFrame(), to, mass, stiffness, damping,
                          std::move(completion));
  }

  void RestoreWindow(double width, double height,
                     std::function<void()> completion) {
    if (!oldFrame_) {
      if (completion) completion();
      return;
    }
    Frame target = *oldFrame_;
    target.w = width;
    target.h = height;

    double s = Scale();
    RECT screen = MonitorRect();
    double sw = screen.right - screen.left;
    Frame collapse{screen.left + (sw - 160 * s) / 2.0, (double)screen.top,
                   160 * s, 20 * s};

    SpringAnimate(collapse, 1, 150, 25, [=]() {
      SetRoundedCorners(hwnd_, true);
      SetBlur(hwnd_, true);
      SpringAnimate(target, 1, 220, 25, [=]() {
        oldFrame_.reset();
        if (completion) completion();
      });
    });
  }

  HWND hwnd_;
  bool isIsland_ = false;
  std::optional<double> anchorX_, anchorY_;
  std::optional<Frame> oldFrame_;
};

// ---------------------------------------------------------------------------

std::unique_ptr<WindowController> g_controller;
std::unique_ptr<Channel> g_animationChannel, g_notchChannel, g_iconChannel;

}  // namespace

void SetupWindowChannels(flutter::BinaryMessenger* messenger, HWND hwnd) {
  Gdiplus::GdiplusStartupInput gdiInput;
  Gdiplus::GdiplusStartup(&g_gdiplusToken, &gdiInput, nullptr);

  ApplyBaseWindowStyle(hwnd);
  g_hwnd = hwnd;
  SetWindowSubclass(hwnd, RegionSubclassProc, 1, 0);
  SetTimer(hwnd, kKeepOnTopTimerId, 500, &KeepOnTopProc);
  g_initialFrontTicks = 0;
  SetTimer(hwnd, kInitialFrontTimerId, 400, &InitialFrontProc);
  g_controller = std::make_unique<WindowController>(hwnd);

  // ---- window/animation ----
  g_animationChannel = std::make_unique<Channel>(
      messenger, "window/animation", &flutter::StandardMethodCodec::GetInstance());
  g_animationChannel->SetMethodCallHandler(
      [](const MethodCall& call, std::unique_ptr<flutter::MethodResult<EncodableValue>> r) {
        ResultPtr result(std::move(r));
        if (call.method_name() == "isMouseInsideWindow") {
          result->Success(EncodableValue(g_controller->IsMouseInside()));
        } else if (call.method_name() == "resize") {
          auto* args = std::get_if<EncodableMap>(call.arguments());
          std::optional<double> w, h, d;
          std::optional<std::string> curve;
          if (args) {
            w = GetNum(*args, "width");
            h = GetNum(*args, "height");
            d = GetNum(*args, "duration");
            curve = GetStr(*args, "curve");
          }
          if (!w || !h || !d || !curve) {
            result->Error("BAD_ARGS", "Invalid args");
            return;
          }
          g_controller->AnimateResize(*w, *h, *d,
                                      [result]() { result->Success(EncodableValue(true)); });
        } else {
          result->NotImplemented();
        }
      });

  // ---- window/notch ----
  g_notchChannel = std::make_unique<Channel>(
      messenger, "window/notch", &flutter::StandardMethodCodec::GetInstance());
  g_notchChannel->SetMethodCallHandler(
      [](const MethodCall& call, std::unique_ptr<flutter::MethodResult<EncodableValue>> r) {
        ResultPtr result(std::move(r));
        if (call.method_name() == "moveToNotch") {
          auto* args = std::get_if<EncodableMap>(call.arguments());
          std::optional<double> w, h, wi, hi;
          if (args) {
            w = GetNum(*args, "width");
            h = GetNum(*args, "height");
            wi = GetNum(*args, "width_dynamic_island");
            hi = GetNum(*args, "height_dynamic_island");
          }
          if (!w || !h || !wi || !hi) {
            result->Error("BAD_ARGS", "Invalid args");
            return;
          }
          g_controller->MoveToNotch(*w, *h, *wi, *hi,
                                    [result]() { result->Success(EncodableValue(true)); });
        } else {
          result->NotImplemented();
        }
      });

  // ---- app.icon ----
  g_iconChannel = std::make_unique<Channel>(
      messenger, "app.icon", &flutter::StandardMethodCodec::GetInstance());
  g_iconChannel->SetMethodCallHandler(
      [](const MethodCall& call, std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        auto* args = std::get_if<EncodableMap>(call.arguments());
        auto path = args ? GetStr(*args, "path") : std::nullopt;

        if (call.method_name() == "resolveShortcut") {
          if (!path) {
            result->Success(EncodableValue());
            return;
          }
          auto target = ResolveShortcut(Utf8ToWide(*path));
          if (!target) {
            result->Success(EncodableValue());  // не удалось -> null
            return;
          }
          result->Success(EncodableValue(WideToUtf8(*target)));
          return;
        }
        if (call.method_name() != "getIcon") {
          result->NotImplemented();
          return;
        }
        if (!path) {
          result->Success(EncodableValue());  // nil
          return;
        }
        auto png = GetIconPng(Utf8ToWide(*path));
        if (!png) {
          result->Success(EncodableValue());
          return;
        }
        result->Success(EncodableValue(std::move(*png)));
      });
}

void TeardownWindowChannels() {
  if (g_hwnd) {
    KillTimer(g_hwnd, kKeepOnTopTimerId);
    KillTimer(g_hwnd, kInitialFrontTimerId);
    RemoveWindowSubclass(g_hwnd, RegionSubclassProc, 1);
  }
  g_hwnd = nullptr;
  Animator::Get().Cancel();
  g_animationChannel.reset();
  g_notchChannel.reset();
  g_iconChannel.reset();
  g_controller.reset();
  if (g_gdiplusToken) {
    Gdiplus::GdiplusShutdown(g_gdiplusToken);
    g_gdiplusToken = 0;
  }
}
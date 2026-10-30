import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/service/app_service.dart';
import 'package:dynamic_lake_macos/service/icon_service.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';
import 'package:dynamic_lake_macos/view/app_open.dart';
import 'package:dynamic_lake_macos/view/drop_file.dart';
import 'package:dynamic_lake_macos/view/main_widgets.dart';
import 'package:dynamic_lake_macos/view/music.dart';
import 'package:dynamic_lake_macos/view/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class DynamicIslandMain extends StatefulWidget {
  const DynamicIslandMain({super.key});

  @override
  State<DynamicIslandMain> createState() => _DynamicIslandMainState();
}

class _DynamicIslandMainState extends State<DynamicIslandMain> {
  static const notchChannel = MethodChannel('window/notch');
  late MainAppController _mainAppController;
  static ValueNotifier<int> pageIndex = ValueNotifier(0);
  final pageDynamicIslandMax = 4;
  bool nextPageAnimated = false;

  void nextPage(MainAppController mainAppController, {int? page}) {
    if (nextPageAnimated || _mainAppController.animatedChangeDynamicIsland || _mainAppController.isAnimating) return;
    nextPageAnimated = true;
    int newPage = pageIndex.value;
    if (page == null) {
      pageIndex.value >= pageDynamicIslandMax - 1 ? newPage = 0 : newPage++;
    } else {
      newPage = page;
    }
    Future.delayed(const Duration(milliseconds: 150), () {
      pageIndex.value = newPage;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      nextPageAnimated = false;
    });
    mainAppController.stateScreen = pageDynamicIsland.keys.elementAt(newPage);
    mainAppController.sizeWindow = mainAppController.sizeWindowObjects[mainAppController.stateScreen];
    if (mainAppController.isDynamicIsland) {
      mainAppController.isExpanded
      ? mainAppController.resizeWindow(mainAppController.sizeWindow.expandedSizeBaseDynamicIsland)
      : mainAppController.resizeWindow(mainAppController.sizeWindow.collapsedSizeBaseDynamicIsland);
    } else {
      mainAppController.isExpanded
      ? mainAppController.resizeWindow(mainAppController.sizeWindow.expandedSize)
      : mainAppController.resizeWindow(mainAppController.sizeWindow.collapsedSize);
    }
  }

  void initKeyBind() async {
    List<HotKeyModifier>? modifiersConf;
    if (Platform.isWindows) {
      modifiersConf = [HotKeyModifier.alt];
    } else if (Platform.isMacOS) {
      modifiersConf = [HotKeyModifier.meta];
    }

    final throughHotKey = HotKey(
      key: PhysicalKeyboardKey.keyT,
      modifiers: modifiersConf,
    );

    final hideHotKey = HotKey(
      key: PhysicalKeyboardKey.keyH,
      modifiers: modifiersConf,
    );

    final quitHotKey = HotKey(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: modifiersConf,
    );

    final dynamicIslandHotKey = HotKey(
      key: PhysicalKeyboardKey.keyD,
      modifiers: modifiersConf,
    );


    await hotKeyManager.register(
      throughHotKey,
      keyDownHandler: (_) async {
        _mainAppController.clickThrough = !_mainAppController.clickThrough;

        if (_mainAppController.isDynamicIsland) {
          if (_mainAppController.clickThrough) {
            _mainAppController.requestState(newState: IslandState.collapsed);
          } else if (!_mainAppController.hideApp) {
            windowManager.show();
          }
        }
        await windowManager.setIgnoreMouseEvents(
          _mainAppController.clickThrough,
          forward: true,
        );
      },
    );

    await hotKeyManager.register(
      hideHotKey,
      keyDownHandler: (_) {
        _mainAppController.hidenApp();
      },
    );

    await hotKeyManager.register(
      quitHotKey,
      keyDownHandler: (_) async {
        exit(0);
      },
    );

    await hotKeyManager.register(
      dynamicIslandHotKey,
      keyDownHandler: (_) async {
        try {
          if (_mainAppController.isAnimating || _mainAppController.animatedChangeDynamicIsland) return;
          _mainAppController.animatedChangeDynamicIsland = true;
          await _mainAppController.requestState(newState: IslandState.collapsed, waitResized: true);
          Future.delayed(const Duration(milliseconds: 550), () {
            _mainAppController.isDynamicIsland = !_mainAppController.isDynamicIsland;
            windowManager.setIgnoreMouseEvents(
            _mainAppController.isDynamicIsland ? false : _mainAppController.clickThrough,
              forward: true,
            );
          });
          await notchChannel.invokeMethod('moveToNotch', {
            'width': _mainAppController.sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSize.width,
            'height': _mainAppController.sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSize.height,
            'height_dynamic_island': _mainAppController.sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSizeBaseDynamicIsland.height,
            'width_dynamic_island': _mainAppController.sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSizeBaseDynamicIsland.width,
          });
          _mainAppController.animatedChangeDynamicIsland = false;
        } catch (e) {
          print('Notch error: $e');
        }
      },
    );

    final List<PhysicalKeyboardKey> digitalKeys = [
      PhysicalKeyboardKey.digit1,
      PhysicalKeyboardKey.digit2,
      PhysicalKeyboardKey.digit3,
      PhysicalKeyboardKey.digit4,
      PhysicalKeyboardKey.digit5,
      PhysicalKeyboardKey.digit6,
      PhysicalKeyboardKey.digit7,
      PhysicalKeyboardKey.digit8,
      PhysicalKeyboardKey.digit9,
    ];

    for (int i = 0; i < digitalKeys.length; i++) {
      final int pressedNumber = i + 1;

      HotKey hotKey = HotKey(
        key: digitalKeys[i],
        modifiers: modifiersConf, 
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          nextPage(_mainAppController, page: pressedNumber-1);
        },
      );
    }
  }

  Future<void> initWindowSize() async {
    await windowManager.waitUntilReadyToShow(WindowOptions(
      size: _mainAppController.sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSize,
      center: true,
    ), () {});
  }

  @override
  void initState() {
    super.initState();
    _mainAppController = context.read<MainAppController>();
    initWindowSize();
    initKeyBind();
  }

  final ValueNotifier<bool> _dragging = ValueNotifier(false);
  late Map<StateScreen, Widget> pageDynamicIsland = {
    StateScreen.main: DynamicIslandMainWidgets(),
    StateScreen.music: DynamicIslandMusic(),
    StateScreen.app: DynamicIslandAppOpen(),
    StateScreen.search: DynamicIslandSearch(),

    StateScreen.mainMusic: DynamicIslandMainWidgets(),
    StateScreen.musicPlaylists: DynamicIslandMusic(),
  };

  @override
  Widget build(BuildContext context) {
    _mainAppController.sizeWindow = _mainAppController.sizeWindowObjects[_mainAppController.stateScreen];
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        return DropTarget(
          onDragDone: (detail) async {
            final musicService = context.read<MusicService>();
            final appService = context.read<AppService>();

            for (final file in detail.files) {
              final name = file.name.toLowerCase();

              if (name.endsWith('.mp3')) {
                musicService.addMusic(file.path);
              } else if (Platform.isMacOS && name.endsWith('.app')) {
                appService.addApp(file.path);
              } else if (Platform.isWindows &&
                  (name.endsWith('.exe') || name.endsWith('.lnk') || name.endsWith('.url'))) {
                final path = name.endsWith('.url')
                    ? file.path
                    : await IconService().resolveAppPath(file.path);
                appService.addApp(path);
              }
            }
          },
          onDragEntered: (detail) async {
            _dragging.value = true;
            mainAppController.sizeWindow = SizeWindowObject(
              expandedSizeBaseDynamicIsland: Size(420, 160)
            );
            if (!mainAppController.isDynamicIsland) {
              mainAppController.resizeWindow(Size(140, 140));
            }
          },
          onDragExited: (detail) {
            _dragging.value = false;
            mainAppController.sizeWindow = mainAppController.sizeWindowObjects[mainAppController.stateScreen];
            mainAppController.stateApp = IslandState.collapsed;
            mainAppController.resizeWindow(mainAppController.isDynamicIsland ? mainAppController.sizeWindow.collapsedSizeBaseDynamicIsland : mainAppController.sizeWindow.collapsedSize);
          },
          child: ValueListenableBuilder(
            valueListenable: pageIndex,
            builder: (_, pageIndexValue, _) {
              return ValueListenableBuilder(
                valueListenable: _dragging, 
                builder: (_, draggingValue, _) => !draggingValue ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 70),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: GestureDetector(
                  key: ValueKey('page_$pageIndexValue'),
                  onPanStart: (_) async => (
                    mainAppController.isDynamicIsland || 
                    mainAppController.isAnimating || 
                    mainAppController.animatedChangeDynamicIsland) ? null : windowManager.startDragging(),
                  onTap: () {
                    if (mainAppController.animatedChangeDynamicIsland) return;
                    if (!mainAppController.isDynamicIsland) {
                      if (mainAppController.isAnimating || mainAppController.animatedChangeDynamicIsland) return;
                      try { 
                        mainAppController.requestState();
                      } catch (_) {}
                    } else {
                      nextPage(mainAppController);
                    }
                  },
                  child: buildScaffoldMain(pageDynamicIsland.values.elementAt(pageIndexValue))),
                ) 
                : buildScaffoldMain(DynamicIslandDropFile(), key: ValueKey('page_$pageIndexValue'))
              );
            }
          )
        );
      }
    );
  }

  Widget buildScaffoldMain(
    Widget child,
    {Key? key}
  ) {
    return Scaffold(
      key: key,
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: Consumer<MainAppController>(
          builder: (_, mainAppController, _) => ClipPath(
            clipper: mainAppController.isDynamicIsland ? ConcaveCornersClipper() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: mainAppController.isDynamicIsland ? Colors.black : Colors.transparent,
              ),
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                children: [
                  child
                ],
              )
            )
          )
        ),
      ),
    );
  }
}
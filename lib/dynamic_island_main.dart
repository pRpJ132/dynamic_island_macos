import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/service/app_service.dart';
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
    if (nextPageAnimated == true) return;
    nextPageAnimated = true;
    int newPage = pageIndex.value;
    if (page == null) {
      pageIndex.value == pageDynamicIsland.length - 1 ? newPage = 0 : newPage++;
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
    mainAppController.sizeWindow = sizeWindowObjects[mainAppController.stateScreen];
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
    final throughHotKey = HotKey(
      key: PhysicalKeyboardKey.keyT,
      modifiers: [HotKeyModifier.meta],
    );

    final hideHotKey = HotKey(
      key: PhysicalKeyboardKey.keyH,
      modifiers: [HotKeyModifier.meta],
    );

    final quitHotKey = HotKey(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: [HotKeyModifier.meta],
    );

    final dynamicIslandHotKey = HotKey(
      key: PhysicalKeyboardKey.keyD,
      modifiers: [HotKeyModifier.meta],
    );


    await hotKeyManager.register(
      throughHotKey,
      keyDownHandler: (_) async {
        _mainAppController.clickThrough = !_mainAppController.clickThrough;

        if (_mainAppController.isDynamicIsland) {
          if (_mainAppController.clickThrough) {
            await _mainAppController.requestState(IslandState.collapsed);
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
      keyDownHandler: (_) async {
        _mainAppController.activatedHide = !_mainAppController.activatedHide;
        await _mainAppController.hidenApp();
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
          await _mainAppController.requestState(IslandState.collapsed);
          Future.delayed(const Duration(milliseconds: 550), () {
            _mainAppController.isDynamicIsland = !_mainAppController.isDynamicIsland;
            windowManager.setIgnoreMouseEvents(
            _mainAppController.isDynamicIsland ? false : _mainAppController.clickThrough,
              forward: true,
            );
          });
          await notchChannel.invokeMethod('moveToNotch', {
            'width': sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSize.width,
            'height': sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSize.height,
            'height_dynamic_island': sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSizeBaseDynamicIsland.height,
            'width_dynamic_island': sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSizeBaseDynamicIsland.width,
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
        modifiers: [HotKeyModifier.meta], 
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          if (pageDynamicIslandMax < pressedNumber || _mainAppController.animatedChangeDynamicIsland || _mainAppController.isAnimating) return;
          nextPage(_mainAppController, page: pressedNumber-1);
        },
      );
    }
  }

  Future<void> initWindowSize() async {
    await windowManager.waitUntilReadyToShow(WindowOptions(
      size: sizeWindowObjects[_mainAppController.stateScreen]!.collapsedSize,
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
  };

  Map<StateScreen, SizeWindowObject> sizeWindowObjects = {
    StateScreen.main: SizeWindowObject(
      collapsedSize: Size(260, 80),
      collapsedSizeBaseDynamicIsland: Size(420, 75)
    ),
    StateScreen.music: SizeWindowObject(
      collapsedSizeBaseDynamicIsland: Size(420, 48),
      expandedSize: Size(360, 290),
      expandedSizeBaseDynamicIsland: Size(420, 270),
    ),
    StateScreen.app: SizeWindowObject(
      collapsedSize: Size(420, 95),
      expandedSize: Size(420, 170),
      collapsedSizeBaseDynamicIsland: Size(420, 95),
      expandedSizeBaseDynamicIsland: Size(420, 170),
    ),
    StateScreen.search: SizeWindowObject(
      collapsedSize: Size(320, 50),
      expandedSize: Size(420, 310),
      collapsedSizeBaseDynamicIsland: Size(420, 75),
      expandedSizeBaseDynamicIsland: Size(420, 310),
    ),

    StateScreen.mainMusic: SizeWindowObject(
      collapsedSize: Size(400, 80),
      expandedSize: Size(400, 170),
      collapsedSizeBaseDynamicIsland: Size(420, 75),
    ),
  };

  @override
  Widget build(BuildContext context) {
    _mainAppController.sizeWindow = sizeWindowObjects[_mainAppController.stateScreen];
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        return DropTarget(
          onDragDone: (detail) {
            for (final file in detail.files) {
              if (file.name.toLowerCase().endsWith('.mp3')) {
                context.read<MusicService>().addMusic(file.path);
              } else if (file.name.toLowerCase().endsWith('.app')) {
                context.read<AppService>().addApp(file.path);
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
            mainAppController.sizeWindow = sizeWindowObjects[mainAppController.stateScreen];
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
                        mainAppController.requestState(mainAppController.stateApp == IslandState.expanded ? IslandState.collapsed : IslandState.expanded);
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
import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/service/app_service.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_app_open/dynamic_island_app_open.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_battery.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_drop_file.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_music.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_time.dart';
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

  void initKeyBind() async {
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyJ,
        modifiers: [HotKeyModifier.meta],
      ),
      keyDownHandler: (_) async {
        if (_mainAppController.isDynamicIsland) {
          _mainAppController.activatedHoverHide = !_mainAppController.activatedHoverHide;
          if (_mainAppController.activatedHoverHide) {
            await _mainAppController.requestState(IslandState.collapsed);
          }
          return;
        }
        _mainAppController.clickThrough = !_mainAppController.clickThrough;
        await windowManager.setIgnoreMouseEvents(
          _mainAppController.clickThrough,
          forward: true,
        );
      },
    );

    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyH,
        modifiers: [HotKeyModifier.meta],
      ),
      keyDownHandler: (_) async {
        _mainAppController.activatedHide = !_mainAppController.activatedHide;
        await _mainAppController.hidenApp();
      },
    );

    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyQ,
        modifiers: [HotKeyModifier.meta],
      ),

      keyDownHandler: (_) async {
        exit(0);
      },
    );

    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyG,
        modifiers: [HotKeyModifier.meta],
      ),
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
            'width': sizeWindowObjects[pageIndex.value].collapsedSize.width,
            'height': sizeWindowObjects[pageIndex.value].collapsedSize.height,
            'height_dynamic_island': sizeWindowObjects[pageIndex.value].collapsedSizeBaseDynamicIsland.height,
            'width_dynamic_island': sizeWindowObjects[pageIndex.value].collapsedSizeBaseDynamicIsland.width,
          });
          _mainAppController.animatedChangeDynamicIsland = false;
        } catch (e) {
          print('Notch error: $e');
        }
      },
    );
  }

  Future<void> initWindowSize() async {
    await windowManager.waitUntilReadyToShow(WindowOptions(
      size: sizeWindowObjects[pageIndex.value].collapsedSize,
      center: true,
    ), () {});
  }

  @override
  void initState() {
    super.initState();
    _mainAppController = context.read<MainAppController>();
    initKeyBind();
    initWindowSize();
  }

  final ValueNotifier<bool> _dragging = ValueNotifier(false);
  List<Widget> pageDynamicIsland = [
    DynamicIslandTime(),
    DynamicIslandBattery(),
    // DynamicIslandTimer(),
    DynamicIslandMusic(),
    DynamicIslandAppOpen(),
  ];

  List<SizeWindowObject> sizeWindowObjects = [
    SizeWindowObject(
      collapsedSize: Size(260, 50),
      collapsedSizeBaseDynamicIsland: Size(420, 75)
    ),
    SizeWindowObject(
      expandedSize: Size(200, 140),
      expandedSizeBaseDynamicIsland: Size(420, 160)
    ),
    // SizeWindowObject(
    //   expandedSize: Size(200, 140),
    //   // expandedSizeBaseDynamicIsland: Size(280, 130)
    //   expandedSizeBaseDynamicIsland: Size(420, 190)
    // ),
    SizeWindowObject(
      collapsedSizeBaseDynamicIsland: Size(420, 48),
      expandedSize: Size(360, 290),
      expandedSizeBaseDynamicIsland: Size(420, 270),
    ),
    SizeWindowObject(
      collapsedSize: Size(420, 95),
      expandedSize: Size(420, 170),
      collapsedSizeBaseDynamicIsland: Size(420, 95),
      expandedSizeBaseDynamicIsland: Size(420, 170),
    )
  ];

  @override
  Widget build(BuildContext context) {
    _mainAppController.sizeWindow = sizeWindowObjects[pageIndex.value];
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
            mainAppController.sizeWindow = SizeWindowObject(
              expandedSizeBaseDynamicIsland: Size(420, 160)
            );
            if (!mainAppController.isDynamicIsland) {
              mainAppController.resizeWindow(Size(140, 140));
            }
            _dragging.value = true;
          },
          onDragExited: (detail) {
            mainAppController.sizeWindow = sizeWindowObjects[pageIndex.value];
            mainAppController.stateApp = IslandState.collapsed;
            mainAppController.resizeWindow(mainAppController.isDynamicIsland ? mainAppController.sizeWindow.collapsedSizeBaseDynamicIsland : mainAppController.sizeWindow.collapsedSize);
            _dragging.value = false;
          },
          child: ValueListenableBuilder(
            valueListenable: pageIndex,
            builder: (_, pageIndexValue, _) {
              return ValueListenableBuilder(
                valueListenable: _dragging, 
                builder: (_, draggingValue, _) => !draggingValue ? GestureDetector(
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
                      pageIndex.value == pageDynamicIsland.length - 1 ? pageIndex.value = 0 :pageIndex.value++;
                      mainAppController.sizeWindow = sizeWindowObjects[pageIndex.value];
                      mainAppController.resizeWindow(mainAppController.sizeWindow.expandedSizeBaseDynamicIsland);
                    }
                  },
                  child: buildScaffoldMain(pageDynamicIsland[pageIndexValue])
                ) : buildScaffoldMain(DynamicIslandDropFile())
              );
            }
          )
        );
      }
    );
  }

  Widget buildScaffoldMain(
    Widget child
  ) {
    return Scaffold(
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
              padding: EdgeInsets.symmetric(horizontal: (mainAppController.isDynamicIsland && mainAppController.stateApp != IslandState.expanded) ? 24 : 20),
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
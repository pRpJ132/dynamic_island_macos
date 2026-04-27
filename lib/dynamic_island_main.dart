import 'dart:async';
import 'dart:io';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_battery.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_time.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_timer.dart';
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

  void initKeyBind(BuildContext context) async {
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyJ,
        modifiers: [HotKeyModifier.meta],
      ),
      keyDownHandler: (_) async {
        _mainAppController.clickThrough = !_mainAppController.clickThrough;
        if (_mainAppController.isDynamicIsland) return;
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
        if (_mainAppController.hideApp) {
          await windowManager.show();
          await windowManager.focus();
          _mainAppController.hideApp = false;
        } else {
          await windowManager.hide();
          _mainAppController.hideApp = true;
        }
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
          await notchChannel.invokeMethod('moveToNotch');
          _mainAppController.animatedChangeDynamicIsland = false;
        } catch (e) {
          print('Notch error: $e');
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _mainAppController = context.read<MainAppController>();
    initKeyBind(context);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pageDynamicIsland = [
      DynamicIslandTime(),
      DynamicIslandBattery(),
      DynamicIslandTimer(),
    ];
    List<SizeWindowObject> sizeWindowObjects = [
      SizeWindowObject(),
      SizeWindowObject(
        expandedSize: Size(200, 140),
        expandedSizeBaseDynamicIsland: Size(420, 160)
      ),
      SizeWindowObject(
        expandedSize: Size(200, 140),
        // expandedSizeBaseDynamicIsland: Size(280, 130)
        expandedSizeBaseDynamicIsland: Size(420, 190)
      ),
    ];
    _mainAppController.sizeWindow = sizeWindowObjects[pageIndex.value];
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        return GestureDetector(
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
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: ValueListenableBuilder(
              valueListenable: pageIndex,
              builder: (_, pageIndexValue, _) {
                return pageDynamicIsland[pageIndexValue];
              }
            ),
          )
        );
      }
    );
  }
}
import 'dart:io';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/dynamic_island_time.dart';
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
  static const _channel = MethodChannel('window/animation');
  late MainAppController _mainAppController;

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
          _mainAppController.isDynamicIsland = !_mainAppController.isDynamicIsland;
          if (_mainAppController.isDynamicIsland) {
            await windowManager.setIgnoreMouseEvents(
              false,
              forward: true,
            );
          } else {
            await windowManager.setIgnoreMouseEvents(
              _mainAppController.clickThrough,
              forward: true,
            );
          }
          _mainAppController.stateApp = IslandState.collapsed;
          await notchChannel.invokeMethod('moveToNotch');
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
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        return GestureDetector(
        onPanStart: (_) async => mainAppController.isDynamicIsland ? windowManager.startDragging() : windowManager.startDragging(),
        onTap: () async {
          if (!mainAppController.isDynamicIsland) {
            try {
              if (mainAppController.stateApp == IslandState.expanded) {
                mainAppController.stateApp = IslandState.collapsed;
                await _channel.invokeMethod('resize', {
                  'width': mainAppController.sizeWindow.collapsedSize.width,
                  'height': mainAppController.sizeWindow.collapsedSize.height,
                  'duration': 0.2,
                  'curve': 'easeInOut',
                });
              } else {
                mainAppController.stateApp = IslandState.expanded;
                await _channel.invokeMethod('resize', {
                  'width': mainAppController.sizeWindow.expandedSize.width,
                  'height': mainAppController.sizeWindow.expandedSize.height,
                  'duration': 0.2,
                  'curve': 'easeInOut',
                });
              }
            } catch (_) {}
          }
        },
        child: DynamicIslandTime(),
      );}
    );
  }
}
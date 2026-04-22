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
  late MainAppController mainAppController;

  void initKeyBind(BuildContext context) async {
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyJ,
        modifiers: [HotKeyModifier.meta],
      ),
      keyDownHandler: (_) async {
        mainAppController.clickThrough = !mainAppController.clickThrough;
        if (mainAppController.isDynamicIsland) return;
        await windowManager.setIgnoreMouseEvents(
          mainAppController.clickThrough,
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
        if (mainAppController.hideApp) {
          await windowManager.show();
          await windowManager.focus();
          mainAppController.hideApp = false;
        } else {
          await windowManager.hide();
          mainAppController.hideApp = true;
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
          mainAppController.isDynamicIsland = !mainAppController.isDynamicIsland;
          if (mainAppController.isDynamicIsland) {
            await windowManager.setIgnoreMouseEvents(
              false,
              forward: true,
            );
          } else {
            await windowManager.setIgnoreMouseEvents(
              mainAppController.clickThrough,
              forward: true,
            );
          }
          mainAppController.stateApp = IslandState.collapsed;
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
    mainAppController = context.read<MainAppController>();
    initKeyBind(context);
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        return GestureDetector(
        onPanStart: (_) async => mainAppController.isDynamicIsland ? null : windowManager.startDragging(),
        child: DynamicIslandTime(),
      );}
    );
  }
}
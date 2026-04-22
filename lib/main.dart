import 'dart:io';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/dynamic_island_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

const notchChannel = MethodChannel('window/notch');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  await windowManager.waitUntilReadyToShow(WindowOptions(
    size: Size(160, 50),
    center: true,
  ), () {});

  final mainAppController = MainAppController();

  await hotKeyManager.register(
    HotKey(
      key: PhysicalKeyboardKey.keyJ,
      modifiers: [HotKeyModifier.meta],
    ),
    keyDownHandler: (_) async {
      mainAppController.clickThrough = !mainAppController.clickThrough;

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
        await notchChannel.invokeMethod('moveToNotch');
      } catch (e) {
        print('Notch error: $e');
      }
    },
  );

  runApp(const DynamicIslandApp());
}

class DynamicIslandApp extends StatelessWidget {
  const DynamicIslandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DynamicIslandTime(),
    );
  }
}
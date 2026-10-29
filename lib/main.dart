import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/dynamic_island_main.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/service/app_service.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  await windowManager.waitUntilReadyToShow(WindowOptions(
    size: SizeWindowObject().collapsedSize,
    center: true,
  ), () {});

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainAppController()),
        ChangeNotifierProvider(create: (_) => MusicService()),
        ChangeNotifierProvider(create: (_) => AppService()),
      ],
      child: DynamicIslandApp(),
    ),
  );
}

class DynamicIslandApp extends StatelessWidget {
  const DynamicIslandApp({super.key});

  @override
  Widget build(BuildContext context) {
    // context.read<MusicService>();
    // context.read<AppService>();
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DynamicIslandMain(),
    );
  }
}
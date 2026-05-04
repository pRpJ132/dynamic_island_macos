import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppService extends ChangeNotifier {
  static const String _key = 'app_list';

  final List<String> _appPaths = [];

  List<String> get apps => _appPaths;

  AppService() {
    loadApp();
  }

  Future<void> loadApp() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    _appPaths
      ..clear()
      ..addAll(list);

    notifyListeners();
  }

  Future<void> addApp(String path) async {
    if (_appPaths.contains(path)) return;

    _appPaths.add(path);
    await _save();
    notifyListeners();
  }

  Future<void> removeApp(String path) async {
    _appPaths.remove(path);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _appPaths.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _appPaths);
  }
}
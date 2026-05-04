import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicService extends ChangeNotifier {
  static const String _key = 'music_list';

  final List<String> _musicPaths = [];

  List<String> get music => _musicPaths;

  MusicService() {
    loadMusic();
  }

  Future<void> loadMusic() async {
    print("object");
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    _musicPaths
      ..clear()
      ..addAll(list);

    notifyListeners();
  }

  Future<void> addMusic(String path) async {
    if (_musicPaths.contains(path)) return;

    _musicPaths.add(path);
    await _save();
    notifyListeners();
  }

  Future<void> removeMusic(String path) async {
    _musicPaths.remove(path);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _musicPaths.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _musicPaths);
  }
}
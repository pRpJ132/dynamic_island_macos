import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _storageKey = 'dynamic_island_search_history';
  static const int _maxItems = 20;

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? <String>[];
  }

  Future<void> addQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_storageKey) ?? <String>[];

    final updated = <String>[
      normalized,
      ...current.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(_maxItems).toList();

    await prefs.setStringList(_storageKey, updated);
  }

  Future<void> removeQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_storageKey) ?? <String>[];
    current.removeWhere((item) => item == query);
    await prefs.setStringList(_storageKey, current);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

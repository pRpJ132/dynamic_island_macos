import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SearchService {
  SearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<String>> suggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.https(
      'suggestqueries.google.com',
      '/complete/search',
      <String, String>{
        'client': 'firefox',
        'hl': 'ru',
        'q': q,
      },
    );

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.length < 2 || decoded[1] is! List) {
        return const [];
      }

      return (decoded[1] as List)
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .take(8)
          .toList();
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  void dispose() => _client.close();
}

import 'package:flutter/services.dart';

class MacIconService {
  static const _channel = MethodChannel('app.icon');

  static Future<Uint8List?> getIcon(String path) async {
    final data = await _channel.invokeMethod('getIcon', {
      'path': path,
    });

    return data != null ? Uint8List.fromList(List<int>.from(data)) : null;
  }
}
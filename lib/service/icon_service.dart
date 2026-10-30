import 'dart:io';

import 'package:flutter/services.dart';

class IconService {
  static const _channel = MethodChannel('app.icon');

  static Future<Uint8List?> getIcon(String path) async {
    final data = await _channel.invokeMethod('getIcon', {
      'path': path,
    });

    return data != null ? Uint8List.fromList(List<int>.from(data)) : null;
  }

  Future<String> resolveAppPath(String path) async {
    if (!Platform.isWindows || !path.toLowerCase().endsWith('.lnk')) return path;
    try {
      final target =
          await _channel.invokeMethod<String>('resolveShortcut', {'path': path});
      return (target != null && target.isNotEmpty) ? target : path;
    } catch (_) {
      return path;
    }
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'package:dynamic_lake_macos/service/mac_icon_service.dart';
import 'package:path_provider/path_provider.dart';

class DiskCache {
  Future<File> _file(String key) async {
    final dir = await getApplicationDocumentsDirectory();

    final cacheDir = Directory('${dir.path}/icon_cache_dynamic_island');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final name = Uri.encodeComponent(key);
    return File('${cacheDir.path}/cache_$name');
  }

  Future<Uint8List?> get(String key) async {
    final file = await _file(key);
    if (await file.exists()) {
      return file.readAsBytes();
    }
    return null;
  }

  Future<void> put(String key, Uint8List bytes) async {
    final file = await _file(key);
    await file.writeAsBytes(bytes, flush: true);
  }
}

class LruMemoryCache {
  static final int maxSize = 200;
  static final _cache = <String, Uint8List>{};
  static final _order = <String>[];


  Uint8List? get(String key) {
    if (!_cache.containsKey(key)) return null;

    _order.remove(key);
    _order.add(key);

    return _cache[key];
  }

  void put(String key, Uint8List value) {
    if (_cache.containsKey(key)) {
      _order.remove(key);
    }

    _cache[key] = value;
    _order.add(key);

    if (_cache.length > maxSize) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
  }
}

class IconRepository {
  static final LruMemoryCache memoryCache = LruMemoryCache();
  static final DiskCache diskCache = DiskCache();

  static final Map<String, Future<Uint8List?>> _inFlight = {};

  Future<Uint8List?> getIcon(String path) {
    return _inFlight.putIfAbsent(path, () async {
      try {
        final mem = memoryCache.get(path);
        if (mem != null) return mem;

        final disk = await diskCache.get(path);
        if (disk != null) {
          memoryCache.put(path, disk);
          return disk;
        }

        final icon = await MacIconService.getIcon(path);

        if (icon != null) {
          memoryCache.put(path, icon);
          await diskCache.put(path, icon);
        }
        return icon;
      } finally {
        _inFlight.remove(path);
      }
    });
  }
}
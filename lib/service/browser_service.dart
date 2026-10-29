import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserOption {
  const BrowserOption({required this.name, this.executablePath});

  final String name;
  final String? executablePath;

  @override
  String toString() => name;
}

class BrowserService {
  static final BrowserService _instance = BrowserService._internal();
  factory BrowserService() => _instance;
  BrowserService._internal();

  static const String _storageKey = 'dynamic_island_search_browser';

  Future<String?> getSaveBrowser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  Future<List<BrowserOption>> discoverBrowsers() async {
    if (kIsWeb) return const [];

    if (Platform.isMacOS) {
      final candidates = <BrowserOption>[
        const BrowserOption(name: 'Safari', executablePath: '/Applications/Safari.app'),
        const BrowserOption(name: 'Google Chrome', executablePath: '/Applications/Google Chrome.app'),
        const BrowserOption(name: 'Firefox', executablePath: '/Applications/Firefox.app'),
        const BrowserOption(name: 'Microsoft Edge', executablePath: '/Applications/Microsoft Edge.app'),
        const BrowserOption(name: 'Brave', executablePath: '/Applications/Brave Browser.app'),
      ];
      final home = Platform.environment['HOME'];
      final found = <BrowserOption>[];
      for (final browser in candidates) {
        final path = browser.executablePath!;
        if (await Directory(path).exists()) found.add(browser);
        if (home != null) {
          final localPath = '$home/Applications/${path.split('/').last}';
          if (await Directory(localPath).exists() &&
              !found.any((b) => b.name == browser.name)) {
            found.add(BrowserOption(name: browser.name, executablePath: localPath));
          }
        }
      }
      return found;
    }

    if (Platform.isWindows) {
      final candidates = <BrowserOption>[
        BrowserOption(name: 'Google Chrome', executablePath: _windowsPath('PROGRAMFILES', r'Google\Chrome\Application\chrome.exe')),
        BrowserOption(name: 'Google Chrome', executablePath: _windowsPath('PROGRAMFILES(X86)', r'Google\Chrome\Application\chrome.exe')),
        BrowserOption(name: 'Microsoft Edge', executablePath: _windowsPath('PROGRAMFILES(X86)', r'Microsoft\Edge\Application\msedge.exe')),
        BrowserOption(name: 'Microsoft Edge', executablePath: _windowsPath('PROGRAMFILES', r'Microsoft\Edge\Application\msedge.exe')),
        BrowserOption(name: 'Firefox', executablePath: _windowsPath('PROGRAMFILES', r'Mozilla Firefox\firefox.exe')),
        BrowserOption(name: 'Brave', executablePath: _windowsPath('LOCALAPPDATA', r'BraveSoftware\Brave-Browser\Application\brave.exe')),
      ];
      final found = <BrowserOption>[];
      for (final browser in candidates) {
        final path = browser.executablePath;
        if (path != null && await File(path).exists() &&
            !found.any((b) => b.name == browser.name)) {
          found.add(browser);
        }
      }
      return found;
    }

    return const [];
  }

  String? _windowsPath(String envKey, String relative) {
    final root = Platform.environment[envKey];
    if (root == null || root.isEmpty) return null;
    return '$root\\$relative';
  }

  Future<void> selectBrowser(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, name);
  }

  Future<bool> openSearch(
    String query, {
    String? browserName,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return false;
    final uri = Uri.https('www.google.com', '/search', {'q': q});
    final wanted = (browserName ?? '').trim();

    try {
      if (wanted.isNotEmpty && Platform.isMacOS) {
        final browsers = await discoverBrowsers();
        final browser = browsers.where((b) => b.name == wanted).firstOrNull;
        final path = browser?.executablePath;
        if (path != null) {
          final result = await Process.run('open', ['-a', path, uri.toString()]);
          if (result.exitCode == 0) return true;
        }
      } else if (wanted.isNotEmpty && Platform.isWindows) {
        final browsers = await discoverBrowsers();
        final browser = browsers.where((b) => b.name == wanted).firstOrNull;
        final path = browser?.executablePath;
        if (path != null) {
          final result = await Process.run(path, [uri.toString()]);
          if (result.exitCode == 0) return true;
        }
      }
    } catch (_) {
      // Fall through to the system browser.
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

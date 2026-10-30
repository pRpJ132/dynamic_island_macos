import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Playlist {
  final String id;
  String name;
  final List<String> tracks;

  Playlist({required this.id, required this.name, List<String>? tracks})
      : tracks = tracks ?? [];

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'tracks': tracks};

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        tracks: (json['tracks'] as List?)?.cast<String>().toList() ?? [],
      );
}

enum RepeatMode { off, all, one }

class MusicService extends ChangeNotifier {
  static const String _keyLibrary = 'music_list';
  static const String _keyPlaylists = 'playlists_v1';
  static const String _keySelected = 'selected_playlist_v1';
  static const String _keyShuffle = 'shuffle_enabled';
  static const String _keyRepeat = 'repeat_mode';
  static const String _libraryId = '__all__';


  final List<String> _musicPaths = [];
  final List<Playlist> _playlists = [];

  String? _selectedPlaylistId;

  List<String> get music => _musicPaths;
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  String? get selectedPlaylistId => _selectedPlaylistId;

  Playlist? get selectedPlaylist =>
      _playlists.where((p) => p.id == _selectedPlaylistId).firstOrNull;

  List<String> get visibleTracks => selectedPlaylist?.tracks ?? _musicPaths;

  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal() {
    loadMusic();

    stateSubscription = playerMusic.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (repeatMode.value == RepeatMode.one &&
            currentTrack.value.isNotEmpty) {
          await playerMusic.seek(Duration.zero);
          await playerMusic.play();
          return;
        }
        final nextIndex = _advance();
        if (nextIndex != null) {
          await _playIndex(nextIndex);
        } else {
          _queueIndex = -1;
          _orderPos = -1;
          isPlayingMusic.value = false;
          currentTrack.value = "";
          notifyListeners();
        }
      } else {
        isPlayingMusic.value = state.playing;
        notifyListeners();
      }
    });
  }

  Future<void> loadMusic() async {
    final prefs = await SharedPreferences.getInstance();

    _musicPaths
      ..clear()
      ..addAll(prefs.getStringList(_keyLibrary) ?? const []);

    _playlists.clear();
    for (final raw in prefs.getStringList(_keyPlaylists) ?? const <String>[]) {
      try {
        _playlists.add(Playlist.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Playlist load error: $e');
      }
    }

    final selected = prefs.getString(_keySelected);
    _selectedPlaylistId =
        _playlists.any((p) => p.id == selected) ? selected : null;

    shuffleEnabled.value = prefs.getBool(_keyShuffle) ?? false;
    repeatMode.value =
        RepeatMode.values[(prefs.getInt(_keyRepeat) ?? 0).clamp(0, 2)];

    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyLibrary, _musicPaths);
    await prefs.setStringList(
      _keyPlaylists,
      _playlists.map((p) => jsonEncode(p.toJson())).toList(),
    );
    if (_selectedPlaylistId == null) {
      await prefs.remove(_keySelected);
    } else {
      await prefs.setString(_keySelected, _selectedPlaylistId!);
    }
  }

  Future<void> _commit() async {
    _syncQueue();
    notifyListeners();
    await _save();
  }

  Future<void> addMusic(String path) async {
    var changed = false;

    if (!_musicPaths.contains(path)) {
      _musicPaths.add(path);
      changed = true;
    }
    final playlist = selectedPlaylist;
    if (playlist != null && !playlist.tracks.contains(path)) {
      playlist.tracks.add(path);
      changed = true;
    }
    if (changed) await _commit();
  }

  /// Удаляет трек из библиотеки и из всех плейлистов
  Future<void> removeMusic(String path) async {
    _musicPaths.remove(path);
    for (final p in _playlists) {
      p.tracks.remove(path);
    }
    await _commit();
  }

  Future<void> clear() async {
    _musicPaths.clear();
    for (final p in _playlists) {
      p.tracks.clear();
    }
    await _commit();
  }

  Future<String?> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _playlists.add(Playlist(id: id, name: trimmed));
    _selectedPlaylistId = id;
    await _commit();
    return id;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final playlist = _playlists.where((p) => p.id == id).firstOrNull;
    if (playlist == null) return;
    playlist.name = trimmed;
    await _commit();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    if (_selectedPlaylistId == id) _selectedPlaylistId = null;
    await _commit();
  }

  Future<void> selectPlaylist(String? id) async {
    _selectedPlaylistId = _playlists.any((p) => p.id == id) ? id : null;
    notifyListeners();
    await _save();
  }

  Future<void> addToPlaylist(String playlistId, String path) async {
    final playlist = _playlists.where((p) => p.id == playlistId).firstOrNull;
    if (playlist == null || playlist.tracks.contains(path)) return;
    playlist.tracks.add(path);
    await _commit();
  }

  Future<void> removeFromPlaylist(String playlistId, String path) async {
    final playlist = _playlists.where((p) => p.id == playlistId).firstOrNull;
    if (playlist == null) return;
    playlist.tracks.remove(path);
    await _commit();
  }

  Future<void> reorderVisible(int oldIndex, int newIndex) async {
    final list = selectedPlaylist?.tracks ?? _musicPaths;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, list.length - 1);

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _commit();
  }

  List<String> _queue = [];
  int _queueIndex = -1;
  String _queueSource = _libraryId;

  List<int> _order = [];
  int _orderPos = -1;
  final Random _random = Random();

  final ValueNotifier<bool> shuffleEnabled = ValueNotifier(false);
  final ValueNotifier<RepeatMode> repeatMode = ValueNotifier(RepeatMode.off);

  List<String> _tracksOf(String sourceId) {
    if (sourceId == _libraryId) return _musicPaths;
    return _playlists.where((p) => p.id == sourceId).firstOrNull?.tracks ??
        const [];
  }

  void _rebuildOrder() {
    final n = _queue.length;
    final cur = (_queueIndex >= 0 && _queueIndex < n) ? _queueIndex : -1;

    _order = List.generate(n, (i) => i);
    if (shuffleEnabled.value && n > 1) {
      _order.shuffle(_random);
      if (cur >= 0) {
        _order.remove(cur);
        _order.insert(0, cur);
      }
    }
    _orderPos = cur >= 0 ? _order.indexOf(cur) : -1;
  }

  void _syncQueue() {
    if (_queue.isEmpty) return;
    final fresh = List.of(_tracksOf(_queueSource));
    if (listEquals(fresh, _queue)) return;
    _queue = fresh;
    _queueIndex = _queue.indexOf(currentTrack.value);
    _rebuildOrder();
  }

  int? _advance() {
    if (_queue.isEmpty || _order.isEmpty) return null;
    if (_orderPos + 1 < _order.length) return _order[_orderPos + 1];
    if (repeatMode.value == RepeatMode.off) return null;

    if (shuffleEnabled.value && _order.length > 1) {
      _order.shuffle(_random);
      if (_order.first == _queueIndex) {
        final j = 1 + _random.nextInt(_order.length - 1);
        final tmp = _order[0];
        _order[0] = _order[j];
        _order[j] = tmp;
      }
    }
    return _order.first;
  }

  Future<void> playPlaylist(String? id) async {
    final source = id ?? _libraryId;
    final tracks = List.of(_tracksOf(source));
    if (tracks.isEmpty) return;
    _queueSource = source;
    _queue = tracks;
    _queueIndex = shuffleEnabled.value ? _random.nextInt(tracks.length) : 0;
    _rebuildOrder();
    await _playIndex(_queueIndex);
  }

  Future<void> next() async {
    final index = _advance();
    if (index != null) await _playIndex(index);
  }

  Future<void> previous() async {
    if (playerMusic.position > const Duration(seconds: 3)) {
      await playerMusic.seek(Duration.zero);
      return;
    }
    if (_orderPos > 0) {
      await _playIndex(_order[_orderPos - 1]);
    } else if (repeatMode.value != RepeatMode.off && _order.isNotEmpty) {
      await _playIndex(_order.last);
    } else {
      await playerMusic.seek(Duration.zero);
    }
  }

  Future<void> toggleShuffle() async {
    shuffleEnabled.value = !shuffleEnabled.value;
    _rebuildOrder();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShuffle, shuffleEnabled.value);
  }

  Future<void> cycleRepeat() async {
    repeatMode.value =
        RepeatMode.values[(repeatMode.value.index + 1) % RepeatMode.values.length];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRepeat, repeatMode.value.index);
  }

  Future<void> _playIndex(int index, {int attempts = 0}) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    _orderPos = _order.indexOf(index);
    try {
      await _loadTrack(_queue[index]);
      await playerMusic.play();
    } catch (e) {
      debugPrint('Audio error: $e');
      if (attempts < _queue.length) {
        final nextIndex = _advance();
        if (nextIndex != null) {
          await _playIndex(nextIndex, attempts: attempts + 1);
        }
      }
    }
  }

  final AudioPlayer playerMusic = AudioPlayer();
  final ValueNotifier<String> currentTrack = ValueNotifier("");
  final ValueNotifier<bool> isPlayingMusic = ValueNotifier(false);
  final ValueNotifier<Waveform> waveformsMusic = ValueNotifier(Waveform(
      version: 0,
      flags: 0,
      sampleRate: 0,
      samplesPerPixel: 0,
      length: 0,
      data: []));
  late final StreamSubscription stateSubscription;
  final ValueNotifier<double> volumeMusic = ValueNotifier(0.5);
  double _volumeBeforeMute = 0.5;

  Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    volumeMusic.value = v;
    if (v > 0) _volumeBeforeMute = v;
    await playerMusic.setVolume(v);
  }

  Future<void> toggleMute() =>
      setVolume(volumeMusic.value > 0 ? 0 : _volumeBeforeMute);

  Future<void> _loadTrack(String path) async {
    await playerMusic.setFilePath(path);
    currentTrack.value = path;

    if (!Platform.isWindows) {
      final wf = await _extractWaveform(path);
      if (wf != null) waveformsMusic.value = wf;
    }
    await playerMusic.seek(Duration.zero);
  }

  Future<void> playMusic(String path) async {
    try {
      if (currentTrack.value != path) {
        final visible = visibleTracks;
        if (visible.contains(path)) {
          _queueSource = _selectedPlaylistId ?? _libraryId;
          _queue = List.of(visible);
        }
        _queueIndex = _queue.indexOf(path);
        _rebuildOrder();
        await _loadTrack(path);
      }
      await playerMusic.play();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  Future<void> pauseMusic() async {
    await playerMusic.pause();
  }

  Future<Waveform?> _extractWaveform(String path) async {
    try {
      final waveformFile = File('$path.waveform');
      final progressStream = JustWaveform.extract(
        audioInFile: File(path),
        waveOutFile: waveformFile,
      );
      await for (final progress in progressStream) {
        if (progress.waveform != null) {
          return progress.waveform;
        }
      }
    } catch (e) {
      debugPrint('Waveform error: $e');
    }
    return null;
  }
}
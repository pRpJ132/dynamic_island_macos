import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicService extends ChangeNotifier {
  static const String _key = 'music_list';

  final List<String> _musicPaths = [];

  List<String> get music => _musicPaths;

  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal(){
    loadMusic();

    stateSubscription = playerMusic.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        isPlayingMusic.value = false;
        currentTrack.value = "";
      } else {
        isPlayingMusic.value = state.playing;
      }
    });
  }

  Future<void> loadMusic() async {
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



  final AudioPlayer playerMusic = AudioPlayer();
  final ValueNotifier<String> currentTrack = ValueNotifier("");
  final ValueNotifier<bool> isPlayingMusic = ValueNotifier(false);
  final ValueNotifier<Waveform> waveformsMusic = ValueNotifier(Waveform(version: 0, flags: 0, sampleRate: 0, samplesPerPixel: 0, length: 0, data: []));
  late final StreamSubscription stateSubscription;
  final ValueNotifier<double> volumeMusic = ValueNotifier(0.5);
  double _volumeBeforeMute = 0.5;

  Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    volumeMusic.value = v;
    if (v > 0) _volumeBeforeMute = v;
    await playerMusic.setVolume(v);
  }

  Future<void> toggleMute() => setVolume(volumeMusic.value > 0 ? 0 : _volumeBeforeMute);

  Future<void> playMusic(String path) async {
    try {
      if (currentTrack.value != path) {
        await playerMusic.setFilePath(path);
        currentTrack.value = path;

        if (!Platform.isWindows) {
          final wf = await _extractWaveform(path);
          if (wf != null) waveformsMusic.value = wf;
        }
        await playerMusic.seek(Duration.zero);
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
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_local_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:ultimate_flutter_icons/flutter_icons.dart';

class DynamicIslandMusic extends StatefulWidget {
  const DynamicIslandMusic({super.key});

  @override
  State<DynamicIslandMusic> createState() => _DynamicIslandMusicState();
}

class _DynamicIslandMusicState extends State<DynamicIslandMusic> {
  final AudioPlayer player = AudioPlayer();

  final ValueNotifier<String> _currentTrack = ValueNotifier("");
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  final ValueNotifier<Waveform?> _waveforms = ValueNotifier(null);

  StreamSubscription? _playingSubscription;

  @override
  void initState() {
    super.initState();
    _playingSubscription = player.playingStream.listen((playing) {
      _isPlaying.value = playing;
    });
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    player.dispose();
    _currentTrack.dispose();
    _isPlaying.dispose();
    _waveforms.dispose();
    super.dispose();
  }

  Future<void> _play(String path) async {
    try {
      if (_currentTrack.value != path) {
        await player.setFilePath(path);
        _currentTrack.value = path;

        _extractWaveformAsync(path);
      }

      await player.play();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void _extractWaveformAsync(String path) async {
    final wf = await extractWaveform(path);
    if (wf != null && mounted) {
      _waveforms.value = wf;
    }
  }

  Future<void> _pause() async {
    await player.pause();
  }

  Future<Waveform?> extractWaveform(String path) async {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          children: [...previousChildren, ?currentChild],
        ),
        child: mainAppController.stateApp == IslandState.expanded
            ? _ExpandedView(
                key: const ValueKey('expanded'),
                mainAppController: mainAppController,
                isPlaying: _isPlaying,
                currentTrack: _currentTrack,
                onPlay: _play,
                onPause: _pause,
              )
            : _CollapsedView(
                key: const ValueKey('collapsed'),
                mainAppController: mainAppController,
                player: player,
                waveform: _waveforms,
              ),
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final MainAppController mainAppController;
  final ValueNotifier<bool> isPlaying;
  final ValueNotifier<String> currentTrack;
  final Future<void> Function(String path) onPlay;
  final Future<void> Function() onPause;

  const _ExpandedView({
    super.key,
    required this.mainAppController,
    required this.isPlaying,
    required this.currentTrack,
    required this.onPlay,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicLocalService>(
      builder: (_, service, _) {
        final tracks = service.music;

        if (tracks.isEmpty) {
          return const Center(
            child: Text(
              'Нет треков',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 18),
          itemCount: tracks.length,
          itemBuilder: (_, index) {
            final path = tracks[index];
            final name = path.split('/').last;

            return ListTile(
              dense: true,
              leading: ValueListenableBuilder<String>(
                valueListenable: currentTrack,
                builder: (_, currentTrackValue, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: isPlaying,
                    builder: (_, isPlayingValue, _) {
                      final isCurrentAndPlaying =
                          currentTrackValue == path && isPlayingValue;
                      return IconButton(
                        icon: FIcon(
                          isCurrentAndPlaying ? FA.FaPause : FA.FaPlay,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: () {
                          if (isCurrentAndPlaying) {
                            onPause();
                          } else {
                            onPlay(path);
                          }
                        },
                      );
                    },
                  );
                },
              ),
              title: SizedBox(
                height: 18,
                child: Marquee(
                  text: name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  scrollAxis: Axis.horizontal,
                  blankSpace: 30,
                  pauseAfterRound: const Duration(seconds: 3),
                  accelerationDuration: const Duration(seconds: 3),
                  decelerationDuration: const Duration(milliseconds: 500),
                ),
              ),
              trailing: IconButton(
                icon: const FIcon(FA.FaTrash, color: Colors.white, size: 16),
                onPressed: () => service.removeMusic(path),
              ),
            );
          },
        );
      },
    );
  }
}

class _CollapsedView extends StatefulWidget {
  final MainAppController mainAppController;
  final AudioPlayer player;
  final ValueNotifier<Waveform?> waveform;

  const _CollapsedView({
    super.key,
    required this.mainAppController,
    required this.player,
    required this.waveform,
  });

  @override
  State<_CollapsedView> createState() => _CollapsedViewState();
}

class _CollapsedViewState extends State<_CollapsedView>
    with SingleTickerProviderStateMixin {
  final List<double> _previousHeights = List.filled(60, 4.0, growable: true);
  late final Ticker _ticker;
  StreamSubscription? _positionSub;
  final ValueNotifier<double> _visualPhase = ValueNotifier(0.0);
  double _targetPhase = 0.0;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.player.positionStream.listen((position) {
      final duration = widget.player.duration;
      if (duration == null || duration.inMilliseconds <= 0) return;
      _targetPhase = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    });

    _ticker = createTicker((Duration elapsed) {
      if (!widget.player.playing) return;
      final newPhase = _visualPhase.value + (_targetPhase - _visualPhase.value) * 0.85;
      _visualPhase.value = newPhase;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ticker.dispose();
    _visualPhase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Consumer<MusicLocalService>(
        builder: (_, service, _) => Row(
          mainAxisAlignment: widget.mainAppController.isDynamicIsland
              ? MainAxisAlignment.end
              : MainAxisAlignment.center,
          children: [
            const SizedBox(width: 5),
              ValueListenableBuilder(
                valueListenable: widget.waveform,
                builder: (_, waveformValue, _) => (waveformValue != null && widget.player.playing) ? SizedBox(
                  width: 60,
                  height: 25,
                  child: ValueListenableBuilder(
                    valueListenable: _visualPhase,
                    builder: (_, visualPhaseValue, _) {
                      return CustomPaint(
                        painter: WaveformPainter(
                          waveformValue,
                          phase: visualPhaseValue,
                          previousHeights: _previousHeights,
                        ),
                      );
                    }
                  ),
                ) : SizedBox.shrink()
              ),
            const SizedBox(width: 5),
            Text(
              '${service.music.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.music_note, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final Waveform waveform;
  final double phase;
  final Color color;
  final List<double> previousHeights;

  WaveformPainter(
    this.waveform, {
    required this.previousHeights,
    this.phase = 0.0,
    this.color = Colors.white,
  });

  double _ease(double t) => t * t * (3 - 2 * t);

  double _sample(List<int> samples, double index) {
    final int i0 = index.floor().clamp(0, samples.length - 1);
    final int i1 = (i0 + 1).clamp(0, samples.length - 1);
    final double t = index - index.floor();
    return samples[i0] * (1 - t) + samples[i1] * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final samples = waveform.data;
    if (samples.isEmpty) return;

    final centerY = size.height / 2;
    const double barWidth = 3.0;
    const double gap = 2.0;
    const double step = barWidth + gap;

    final int barCount = (size.width / step).floor().clamp(8, 60);

    if (previousHeights.length != barCount) {
      previousHeights.clear();
      previousHeights.addAll(List.filled(barCount, 4.0));
    }

    final paint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final double offset = phase * samples.length;

    for (int i = 0; i < barCount; i++) {
      final double x = i * step + barWidth / 2;

      final double stepSample = samples.length / barCount;
      final double sampleIndex = (offset + i * stepSample) % samples.length;

      double normalized = (_sample(samples, sampleIndex) / 255.0).clamp(0.0, 1.0);
      normalized = _ease(normalized);

      final double maxBarHalf = size.height * 0.45;
      final double targetHeight = (normalized * maxBarHalf).clamp(4.0, maxBarHalf);

      double currentHeight = previousHeights[i];
      currentHeight = _lerp(currentHeight, targetHeight, 0.28);
      previousHeights[i] = currentHeight;

      final double centerDist = ((i / barCount) - 0.5).abs() * 2.0;
      final double fade = pow(1.0 - centerDist, 1.5).toDouble();

      paint.color = color.withOpacity(
        (0.4 + normalized * 0.6) * fade,
      );

      canvas.drawLine(
        Offset(x, centerY - currentHeight),
        Offset(x, centerY + currentHeight),
        paint,
      );
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
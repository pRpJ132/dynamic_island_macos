import 'dart:async';
import 'dart:math';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:flutter/material.dart';
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
  @override
  Widget build(BuildContext context) {
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) => Consumer<MusicService>(
        builder: (_, musicService, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            children: [...previousChildren, ?currentChild],
          ),
          child: mainAppController.stateApp == IslandState.expanded
            ? _ExpandedView(
              musicService: musicService,
            )
            : _CollapsedView(
              mainAppController: mainAppController,
              musicService: musicService
            ),
        ),
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final MusicService musicService;

  const _ExpandedView({
    required this.musicService,
  });

  String formatDuration(Duration? d) {
    if (d == null) return "0:00";

    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return "${minutes.toString().padLeft(2, '0')}:"
          "${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final player = musicService.playerMusic;
    return Consumer<MusicService>(
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

        return Column(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 150,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  itemCount: tracks.length,
                  itemBuilder: (_, index) {
                    final path = tracks[index];
                    final name = path.split('/').last;
                
                    return ListTile(
                      dense: true,
                      leading: ValueListenableBuilder(
                        valueListenable: musicService.currentTrack,
                        builder: (_, currentTrackValue, _) => ValueListenableBuilder<bool>(
                          valueListenable: musicService.isPlayingMusic,
                          builder: (_, isPlayingValue, _) {
                            final isCurrentAndPlaying = currentTrackValue == path && isPlayingValue;
                            return IconButton(
                              icon: FIcon(
                                isCurrentAndPlaying ? FA.FaPause : FA.FaPlay,
                                color: Colors.white,
                                size: 16,
                              ),
                              onPressed: () {
                                if (isCurrentAndPlaying) {
                                  musicService.pauseMusic();
                                } else {
                                  musicService.playMusic(path);
                                }
                              },
                            );
                          },
                        )
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
                ),
              ),
            ),
            SizedBox(height: 15),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  spacing: 2,
                  crossAxisAlignment: .end,
                  children: [
                    Flexible(
                      child: ValueListenableBuilder(
                        valueListenable: musicService.waveformsMusic,
                        builder: (_, waveformValue, _) {
                          return SizedBox(
                            width: 39,
                            height: 17,
                            child: WaveformAnimated(
                              player: player,
                              waveformValue: waveformValue, 
                              isPlaying: musicService.isPlayingMusic,
                            ),
                          );
                        },
                      ),
                    ),
                    Flexible(
                      child: Row(
                        children: [
                          StreamBuilder<Duration?>(
                            stream: player.durationStream,
                            builder: (context, snapshot) {
                              return Text(
                                formatDuration(player.duration ?? Duration.zero),
                                style: const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 25,
                              child: StreamBuilder<Duration>(
                                stream: player.positionStream,
                                builder: (context, snapshot) {
                                  final position = snapshot.data ?? Duration.zero;
                                  final duration = player.duration ?? Duration.zero;
                              
                                  final max = duration.inMilliseconds.toDouble();
                                  final value = position.inMilliseconds.clamp(0, max).toDouble();
                              
                                  return ValueListenableBuilder(
                                    valueListenable: musicService.currentTrack,
                                    builder: (_, currentTrackValue, _) {
                                      return Slider(
                                        min: 0,
                                        max: max == 0 ? 1 : max,
                                        value: value,
                                        onChanged: (newValue) {
                                          player.seek(Duration(milliseconds: newValue.toInt()));
                                        },
                                        onChangeStart: (value) => musicService.pauseMusic(),
                                        onChangeEnd: (value) => musicService.playMusic(currentTrackValue),
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.grey,
                                      );
                                    }
                                  );
                                },
                              ),
                            ),
                          ),
                          StreamBuilder<Duration>(
                            stream: player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;

                              return Text(
                                formatDuration(position),
                                style: const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollapsedView extends StatelessWidget {
  final MainAppController mainAppController;
  final MusicService musicService;

  const _CollapsedView({
    required this.mainAppController, 
    required this.musicService,
  });

  @override
  Widget build(BuildContext context) {
    final player = musicService.playerMusic;
    return SizedBox.expand(
      child: Consumer<MusicService>(
        builder: (_, service, _) => Row(
          mainAxisAlignment: mainAppController.isDynamicIsland
              ? MainAxisAlignment.end
              : MainAxisAlignment.center,
          children: [
            const SizedBox(width: 5),
            ValueListenableBuilder(
              valueListenable: musicService.waveformsMusic,
              builder: (_, waveformValue, _) {
                return SizedBox(
                  width: 39,
                  height: 17,
                  child: WaveformAnimated(
                    player: player,
                    waveformValue: waveformValue, 
                    isPlaying: musicService.isPlayingMusic,
                  ),
                );
              },
            ),
            const SizedBox(width: 9),
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

class WaveformAnimated extends StatefulWidget {
  final AudioPlayer player;
  final Waveform waveformValue;
  final ValueNotifier<bool> isPlaying;
  const WaveformAnimated({super.key, required this.player, required this.waveformValue, required this.isPlaying});

  @override
  State<WaveformAnimated> createState() => _WaveformAnimatedState();
}

class _WaveformAnimatedState extends State<WaveformAnimated> with SingleTickerProviderStateMixin {
  final List<double> _previousHeights = List.filled(60, 0.0, growable: true);
  Timer? _timer;
  StreamSubscription? _positionSub;
  final ValueNotifier<double> _visualPhase = ValueNotifier(0.0);
  double _targetPhase = 0.0;

  @override
  void dispose() {
    _stopTimer?.cancel();
    _positionSub?.cancel();
    _timer?.cancel();
    _visualPhase.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _positionSub = widget.player.positionStream.listen((position) {
      final duration = widget.player.duration;
      if (duration == null || duration.inMilliseconds <= 0) return;
      _targetPhase = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!mounted) return;

      if (!widget.isPlaying.value) {
        _visualPhase.value += 0.000001;
        return;
      }
      _visualPhase.value += (_targetPhase - _visualPhase.value) * 0.95;
    });
  }

  Timer? _stopTimer;
  void handlePause(bool isPlayingValue) {
    _stopTimer?.cancel();
    if (!isPlayingValue) {
      _stopTimer = Timer(const Duration(seconds: 3), () {
        if (!isPlayingValue && _timer != null && _timer!.isActive) {
          _stopTimer = null;
          _timer?.cancel();
          _timer = null;
        }
      });
    } else {
      if (_timer == null) _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.isPlaying,
      builder: (_, isPlayingValue, _) {
        handlePause(isPlayingValue);
        return ValueListenableBuilder(
          valueListenable: _visualPhase,
          builder: (_, visualPhaseValue, _) => CustomPaint(
            painter: WaveformPainter(
              widget.waveformValue,
              phase: visualPhaseValue,
              previousHeights: _previousHeights, 
              isPlayng: isPlayingValue,
            ),
          )
        );
      }
    );
  }
}

class WaveformPainter extends CustomPainter {
  final Waveform waveform;
  final double phase;
  final Color color;
  final bool isPlayng;
  final List<double> previousHeights;

  WaveformPainter(
    this.waveform, {
    required this.previousHeights,
    this.phase = 0.0,
    this.color = Colors.white, 
    required this.isPlayng,
  });

  double _sample(List<int> samples, double index) {
    final int i0 = index.floor().clamp(0, samples.length - 1);
    final int i1 = (i0 + 1).clamp(0, samples.length - 1);
    final double t = index - index.floor();
    return samples[i0] * (1 - t) + samples[i1] * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final samples = waveform.data;

    final centerY = size.height / 2;
    const double barWidth = 3.0;
    const double gap = 2.0;
    const double step = barWidth + gap;

    final int barCount = (size.width / step).floor().clamp(8, 20);

    if (previousHeights.length != barCount) {
      previousHeights.clear();
      previousHeights.addAll(List.filled(barCount, 0.0));
    }

    final paint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;


    if (!isPlayng) {
      for (int i = 0; i < barCount; i++) {
        final double x = i * step + barWidth / 2;

        double currentHeight = previousHeights[i];
        double next = _lerpEase(currentHeight, 0.0, 0.7);
        currentHeight = _smoothDamp(currentHeight, next, 0.4);
        previousHeights[i] = currentHeight;

        paint.color = color.withOpacity(0.6);

        canvas.drawLine(
          Offset(x, centerY - currentHeight),
          Offset(x, centerY + currentHeight),
          paint,
        );
      }
      return;
    }

    final double offset = phase * samples.length;

    for (int i = 0; i < barCount; i++) {
      final double x = i * step + barWidth / 2;

      final double stepSample = samples.length / barCount;
      final double sampleIndex = (offset + i * stepSample) % samples.length;

      double normalized = (_sample(samples, sampleIndex) / 255.0).clamp(0.0, 1.0);
      normalized = _easeOut(normalized);

      final double maxBarHalf = size.height * 0.45;
      final double targetHeight = (normalized * maxBarHalf).clamp(0.0, maxBarHalf);

      double currentHeight = previousHeights[i];
      double next = _lerpEase(currentHeight, targetHeight, 0.2);
      currentHeight = _smoothDamp(currentHeight, next, 0.5);
      previousHeights[i] = currentHeight;

      canvas.drawLine(
        Offset(x, centerY - currentHeight),
        Offset(x, centerY + currentHeight),
        paint,
      );
    }
  }

  double _smoothDamp(double current, double target, double maxDelta) {
    final delta = target - current;
    if (delta.abs() > maxDelta) {
      return current + maxDelta * delta.sign;
    }
    return target;
  }

  double _easeOut(double t) {
    return 1 - pow(1 - t, 4).toDouble();
  }

  double _lerpEase(double a, double b, double t) {
    final easedT = _easeOut(t);
    return a + (b - a) * easedT;
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) => true;
}
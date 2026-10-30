import 'dart:async';
import 'dart:io';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:dynamic_lake_macos/view/music_screen/widgets/playlist_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:provider/provider.dart';

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
              mainAppController: mainAppController,
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
  final MainAppController mainAppController;
  final MusicService musicService;

  const _ExpandedView({
    required this.mainAppController,
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

        return Padding(
          padding: EdgeInsets.only(top: mainAppController.isDynamicIsland ? 30 : 8.0),
          child: Column(
            children: [
              Flexible(child: PlaylistBar(service: service)),
              Expanded(flex: 3, child: PlaylistTrackList(service: service)),
              const SizedBox(height: 6),
              Expanded(
                flex: 1,
                child: ValueListenableBuilder(
                  valueListenable: service.statusMusic,
                  builder: (_, statusMusic, _) {
                    return IgnorePointer(
                      ignoring: statusMusic == StatusMusic.pause,
                      child: AnimatedOpacity(
                        opacity: statusMusic != StatusMusic.pause ? 1 : 0,
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeIn,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: Column(
                            spacing: 2,
                            crossAxisAlignment: .end,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisAlignment: .spaceBetween,
                                  children: [
                                    if (Platform.isMacOS) ...[
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
                                    ] else Flexible(child: SizedBox.expand()),
                                    Flexible(child: VolumeControl(service: musicService)),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: Row(
                                  children: [
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
                                                  onChangeStart: (_) => musicService.pauseMusic(changePosition: true),
                                                  onChangeEnd: (_) => musicService.playMusic(currentTrackValue),
                                                  activeColor: Colors.white,
                                                  inactiveColor: Colors.grey,
                                                );
                                              }
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    StreamBuilder<Duration?>(
                                      stream: player.durationStream,
                                      builder: (context, snapshot) {
                                        return Text(
                                          formatDuration(player.duration ?? Duration.zero),
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
                    );
                  }
                ),
              ),
            ],
          ),
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
            if (Platform.isMacOS)
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

class VolumeControl extends StatelessWidget {
  final MusicService service;
  const VolumeControl({super.key, required this.service});

  IconData _icon(double v) {
    if (v == 0) return Icons.volume_off;
    if (v < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  double _sizeIcon(double v) {
    if (v == 0) return 14.6;
    if (v < 0.5) return 16.5;
    return 14.6;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: service.volumeMusic,
      builder: (_, volume, _) {
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
              service.setVolume(volume + delta);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InkWell(
                  onTap: service.toggleMute,
                  child: Icon(_icon(volume), color: Colors.white, size: _sizeIcon(volume)),
                ),
              ),
              Flexible(
                child: SizedBox(
                  width: 110,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: volume,
                      onChanged: service.setVolume,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WaveformAnimated extends StatefulWidget {
  final AudioPlayer player;
  final Waveform waveformValue;
  final bool isPlaying;
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

      if (!widget.isPlaying) {
        _visualPhase.value += 0.00001;
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
    handlePause(widget.isPlaying);
    return ValueListenableBuilder(
      valueListenable: _visualPhase,
      builder: (_, visualPhaseValue, _) => CustomPaint(
        painter: WaveformPainter(
          widget.waveformValue,
          phase: visualPhaseValue,
          previousHeights: _previousHeights, 
          isPlayng: widget.isPlaying,
        ),
      )
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
    final double t = index.floor() - index;
    return (samples[i0] * (1 - t) + samples[i1] * t) / 255.0;
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
      ..color = const Color.fromARGB(255, 255, 255, 255);


    if (!isPlayng) {
      for (int i = 0; i < barCount; i++) {
        final double x = i * step + barWidth / 2;

        double currentHeight = previousHeights[i];
        currentHeight = _smoothDamp(currentHeight, 0.0, 0.6);
        previousHeights[i] = currentHeight;

        paint.color = color.withValues(alpha: 0.6);

        canvas.drawLine(
          Offset(x, centerY - currentHeight),
          Offset(x, centerY + currentHeight),
          paint,
        );
      }
      return;
    }

    final double offset = phase * samples.length + 0.000005;
    final double stepSample = (samples.length / barCount);

    for (int i = 0; i < barCount; i++) {
      final double x = i * step + barWidth / 2;
      final double sampleIndex = (offset + i * stepSample) % samples.length;

      double normalized = _sample(samples, sampleIndex).clamp(0.0, 1.0);

      final double maxBarHalf = size.height * 0.45;
      final double targetHeight = (normalized * maxBarHalf).clamp(0.0, maxBarHalf);

      double currentHeight = previousHeights[i];
      currentHeight = _smoothDamp(currentHeight, targetHeight, 1.5);
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


  @override
  bool shouldRepaint(covariant WaveformPainter old) => true;
}
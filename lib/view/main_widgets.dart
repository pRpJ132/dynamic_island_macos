import 'dart:async';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:dynamic_lake_macos/view/music_screen/music.dart';
import 'package:dynamic_lake_macos/view/service/battery_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DynamicIslandMainWidgets extends StatefulWidget {
  const DynamicIslandMainWidgets({super.key});

  @override
  State<DynamicIslandMainWidgets> createState() => _DynamicIslandMainWidgetsState();
}

class _DynamicIslandMainWidgetsState extends State<DynamicIslandMainWidgets> {
  late Timer _clockTimer;
  final ValueNotifier<String> _time = ValueNotifier("");

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    );
  }

  void _updateTime() {
    _time.value = DateFormat('HH:mm:ss │ dd MMMM yyyy', 'ru').format(DateTime.now());
  }

  String formatDuration(Duration? d) {
    if (d == null) return "0:00";

    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return "${minutes.toString().padLeft(2, '0')}:"
          "${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(top: mainAppController.isDynamicIsland ? 0 : 8.0),
              child: ValueListenableBuilder<int?>(
                valueListenable: mainAppController.batteryLevel,
                builder: (_, level, _) {
                  return level != null ? Row(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    mainAxisAlignment: .end,
                    spacing: 5,
                    children: [
                      Flexible(
                        child: BatteryIcon(
                          height: 14.4,
                          width: 26,
                          border: 3,
                          level: level,
                          mainAppController: null,
                        ),
                      ),
                  
                      Flexible(
                        child: Text(
                          '$level%',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1,
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                      ),
                    ],
                  ) : SizedBox.expand();
                }
              ),
            ),
            Consumer<MusicService>(
              builder: (_, musicService, _) {
                bool isPlayingMusicValue = musicService.isPlayingMusic;
                return Row(
                  mainAxisAlignment: isPlayingMusicValue ? .spaceBetween : .center,
                  children: [
                    if (isPlayingMusicValue)
                    _buildMusicWidget(mainAppController.isExpanded, musicService),
                    Flexible(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(
                          top: isPlayingMusicValue && mainAppController.isExpanded ? 25 : 0,
                          bottom: mainAppController.isExpanded ? 0 : isPlayingMusicValue ? 5.3 : mainAppController.isDynamicIsland ? 18 : 0,
                        ),
                        child: ValueListenableBuilder<String>(
                          valueListenable: _time,
                          builder: (_, value, _) {
                            return AnimatedAlign(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOut,
                              alignment: mainAppController.isExpanded && !isPlayingMusicValue ? Alignment.center : isPlayingMusicValue 
                                && mainAppController.isExpanded ? Alignment.topCenter : mainAppController.isDynamicIsland || isPlayingMusicValue ? Alignment.bottomCenter : Alignment.center,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: mainAppController.isExpanded ? 0.9 : 1,
                                  ),
                                  fontSize: mainAppController.isExpanded ? isPlayingMusicValue ? 16 : 24 : 14,
                                  fontWeight: mainAppController.isExpanded
                                      ? FontWeight.w300
                                      : FontWeight.w400,
                                ),
                                child: SizedBox(
                                  width: isPlayingMusicValue ? 100 : null,
                                  child: Text(
                                    textAlign: TextAlign.center,
                                    isPlayingMusicValue ? "${value.substring(0, 8)} ${value.substring(10)}" : value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ],
        );
      },
    );
  }

  Widget _buildMusicWidget(
    bool isExpanded,
    MusicService musicService
  ) {
    return Flexible(
      flex: 3,
      child: AnimatedPadding(
        duration: Duration(milliseconds: 330),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(bottom: isExpanded ? 8.0 : 0, left: isExpanded ? 8.0 : 0),
        child: Column(
          mainAxisAlignment: .end,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 330),
              curve: Curves.easeInOut,
              color: Colors.grey,
              width: isExpanded ? 80 : 0,
              height: isExpanded ? 80 : 0,
            ),
            AnimatedPadding(
              duration: Duration(milliseconds: 330),
              curve: Curves.easeInOut,
              padding: EdgeInsetsGeometry.symmetric(horizontal: isExpanded ? 4 : 1),
              child: Row(
                children: [
                  Flexible(
                    child: AnimatedAlign(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: isExpanded ? AlignmentGeometry.bottomRight : AlignmentGeometry.bottomLeft,
                      child: ValueListenableBuilder(
                        valueListenable: musicService.waveformsMusic,
                        builder: (_, waveformValue, _) {
                          return SizedBox(
                            width: 39,
                            height: 17,
                            child: WaveformAnimated(
                              player: musicService.playerMusic,
                              waveformValue: waveformValue, 
                              isPlaying: musicService.isPlayingMusic,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Row(
                children: [
                  SizedBox(
                    width: 43,
                    child: StreamBuilder<Duration?>(
                      stream: musicService.playerMusic.durationStream,
                      builder: (context, snapshot) {
                        return Text(
                          formatDuration(musicService.playerMusic.duration ?? Duration.zero),
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 25,
                      child: StreamBuilder<Duration>(
                        stream: musicService.playerMusic.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = musicService.playerMusic.duration ?? Duration.zero;
                      
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
                                  musicService.playerMusic.seek(Duration(milliseconds: newValue.toInt()));
                                },
                                activeColor: Colors.white,
                                inactiveColor: Colors.grey,
                              );
                            }
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 43,
                    child: StreamBuilder<Duration>(
                      stream: musicService.playerMusic.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                    
                        return Text(
                          formatDuration(position),
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
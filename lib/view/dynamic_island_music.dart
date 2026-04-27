import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_local_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
  final ValueNotifier _isPlaying = ValueNotifier(false);

  @override
  void dispose() {
    player.dispose();
    _currentTrack.dispose();
    _isPlaying.dispose();
    super.dispose();
  }

  Future<void> _play(String path) async {
    try {
      if (_currentTrack.value != path) {
        await player.setFilePath(path);
        _currentTrack.value = path;
      }

      _isPlaying.value = true;
      await player.play();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  Future<void> _pause() async {
    await player.pause();
    _isPlaying.value = false;
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          children: [...previousChildren, ?currentChild],
        ),
        child: mainAppController.stateApp == IslandState.expanded
            ? _ExpandedView(mainAppController: mainAppController, isPlaying: _isPlaying, currentTrack: _currentTrack,)
            : _CollapsedView(mainAppController: mainAppController),
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final MainAppController mainAppController;
  final ValueNotifier isPlaying;
  final ValueNotifier currentTrack;
  const _ExpandedView({required this.mainAppController, required this.isPlaying, required this.currentTrack});

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
              leading: IconButton(
                icon: ValueListenableBuilder(
                  valueListenable: currentTrack,
                  builder: (_, currentTrackValue, _) {
                    return ValueListenableBuilder(
                      valueListenable: isPlaying,
                      builder: (_, isPlayingValue, _) {
                        return FIcon(
                          (currentTrackValue == path && isPlayingValue == true)
                              ? FA.FaPause
                              : FA.FaPlay,
                          color: Colors.white,
                          size: 16,
                        );
                      }
                    );
                  }
                ),
                onPressed: () {
                  final state = context.findAncestorStateOfType<_DynamicIslandMusicState>();
                  final path = service.music[index];
                  if (currentTrack.value == path && isPlaying.value == true) {
                    state?._pause();
                  } else {
                    state?._play(path);
                  }
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

class _CollapsedView extends StatelessWidget {
  final MainAppController mainAppController;
  const _CollapsedView({required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Consumer<MusicLocalService>(
        builder: (_, service, _) => Row(
          mainAxisAlignment: mainAppController.isDynamicIsland
              ? MainAxisAlignment.end
              : MainAxisAlignment.center,
          spacing: 5,
          children: [
            Text(
              '${service.music.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Icon(Icons.music_note, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
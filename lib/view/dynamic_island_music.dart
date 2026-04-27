import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_local_service.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DynamicIslandMusic extends StatelessWidget {
  const DynamicIslandMusic({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Consumer<MainAppController>(
        builder: (_, mainAppController, _) => ClipPath(
          clipper: mainAppController.isDynamicIsland
              ? ConcaveCornersClipper()
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: (mainAppController.isDynamicIsland &&
                      mainAppController.stateApp != IslandState.expanded)
                  ? 24
                  : 20,
            ),
            decoration: BoxDecoration(
              color: mainAppController.isDynamicIsland
                  ? Colors.black
                  : Colors.transparent,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                children: [...previousChildren, ?currentChild],
              ),
              child: mainAppController.stateApp == IslandState.expanded
                  ? _ExpandedView(mainAppController: mainAppController)
                  : _CollapsedView(mainAppController: mainAppController),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final MainAppController mainAppController;
  const _ExpandedView({required this.mainAppController});

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
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tracks.length,
          itemBuilder: (_, index) {
            final path = tracks[index];
            final name = path.split('/').last;

            return ListTile(
              dense: true,
              leading: const Icon(Icons.music_note, color: Colors.white70, size: 18),
              title: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 16),
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
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:ultimate_flutter_icons/flutter_icons.dart';

String fileNameOf(String path) => path.split(RegExp(r'[\\/]')).last;

class MiniIconButton extends StatelessWidget {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const MiniIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: icon,
    );
  }
}

class PlaylistBar extends StatelessWidget {
  final MusicService service;
  const PlaylistBar({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final selectedId = service.selectedPlaylistId;

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _PlaylistChip(
                  label: 'Все',
                  selected: selectedId == null,
                  onTap: () => service.selectPlaylist(null),
                ),
                for (final p in service.playlists)
                  _PlaylistChip(
                    label: p.name,
                    selected: selectedId == p.id,
                    onTap: () => service.selectPlaylist(p.id),
                  ),
                _NewPlaylistChip(onCreate: service.createPlaylist),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: service.shuffleEnabled,
            builder: (_, shuffleOn, _) => MiniIconButton(
              tooltip: shuffleOn ? 'Перемешивание: вкл' : 'Перемешивание: выкл',
              icon: Icon(
                Icons.shuffle,
                size: 18,
                color: shuffleOn ? Colors.white : Colors.white38,
              ),
              onPressed: service.toggleShuffle,
            ),
          ),
          ValueListenableBuilder<RepeatMode>(
            valueListenable: service.repeatMode,
            builder: (_, mode, _) => MiniIconButton(
              tooltip: switch (mode) {
                RepeatMode.off => 'Повтор: выкл',
                RepeatMode.all => 'Повтор: весь список',
                RepeatMode.one => 'Повтор: один трек',
              },
              icon: Icon(
                mode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                size: 18,
                color: mode == RepeatMode.off ? Colors.white38 : Colors.white,
              ),
              onPressed: service.cycleRepeat,
            ),
          ),
          IconButton(
            icon: FIcon(
              service.isPlayingMusic ? FA.FaPause : FA.FaPlay,
              color: Colors.white,
              size: 16,
            ),
            onPressed: () => service.isPlayingMusic
                ? service.pauseMusic()
                : service.playPlaylist(selectedId),
          ),
          if (selectedId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white, size: 18),
              onPressed: () => service.deletePlaylist(selectedId),
            ),
        ],
      ),
    );
  }
}

class _PlaylistChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PlaylistChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewPlaylistChip extends StatefulWidget {
  final Future<String?> Function(String name) onCreate;
  const _NewPlaylistChip({required this.onCreate});

  @override
  State<_NewPlaylistChip> createState() => _NewPlaylistChipState();
}

class _NewPlaylistChipState extends State<_NewPlaylistChip> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) {
        setState(() => _editing = false);
        _controller.clear();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final name = value.trim();
    setState(() => _editing = false);
    _controller.clear();
    if (name.isNotEmpty) await widget.onCreate(name);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _editing
          ? SizedBox(
              width: 120,
              height: 24,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                onSubmitted: _submit,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Название',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            )
          : GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ),
    );
  }
}

class PlaylistTrackList extends StatelessWidget {
  final MusicService service;
  const PlaylistTrackList({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final tracks = service.visibleTracks;
    final playlist = service.selectedPlaylist;
    final mainAppController = context.read<MainAppController>();

    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            playlist == null
                ? 'Нет треков'
                : 'Плейлист пуст. Перетащите mp3 в окно или добавьте треки из «Все»',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: tracks.length,
      onReorderItem: service.reorderVisible,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (_, index) {
        final path = tracks[index];
        final inPlaylists = service.playlists.where((p) => p.tracks.contains(path)).toList();

        return ListTile(
          key: ValueKey(path),
          dense: true,
          leading: ValueListenableBuilder<String>(
            valueListenable: service.currentTrack,
            builder: (_, currentTrackValue, _) =>  IconButton(
              icon: FIcon(
                currentTrackValue == path && service.isPlayingMusic ? FA.FaPause : FA.FaPlay,
                color: Colors.white,
                size: 16,
              ),
              onPressed: () {
                if (currentTrackValue == path && service.isPlayingMusic) {
                  service.pauseMusic();
                } else {
                  service.playMusic(path);
                }
              },
            ),
          ),
          title: SizedBox(
            height: 18,
            child: Marquee(
              text: fileNameOf(path),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              scrollAxis: Axis.horizontal,
              blankSpace: 30,
              pauseAfterRound: const Duration(seconds: 3),
              accelerationDuration: const Duration(seconds: 3),
              decelerationDuration: const Duration(milliseconds: 500),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playlist == null && service.playlists.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Плейлисты',
                  color: mainAppController.isDynamicIsland ? const Color.fromARGB(255, 14, 14, 14) : const Color.fromARGB(237, 67, 66, 66),
                  onSelected: (id) {
                    final isIn = inPlaylists.any((p) => p.id == id);
                    if (isIn) {
                      service.removeFromPlaylist(id, path);
                    } else {
                      service.addToPlaylist(id, path);
                    }
                  },
                  itemBuilder: (_) => [
                    for (final p in service.playlists)
                      PopupMenuItem<String>(
                        value: p.id,
                        height: 32,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              child: p.tracks.contains(path)
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : null,
                            ),
                            Flexible(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.tracks.contains(path)
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: Icon(
                    inPlaylists.isEmpty
                        ? Icons.playlist_add
                        : Icons.playlist_add_check,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              MiniIconButton(
                tooltip: playlist == null
                    ? 'Удалить из библиотеки'
                    : 'Убрать из плейлиста',
                icon: const FIcon(FA.FaTrash, color: Colors.white, size: 14),
                onPressed: () => playlist == null
                    ? service.removeMusic(path)
                    : service.removeFromPlaylist(playlist.id, path),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_handle,
                        color: Colors.white54, size: 18),
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
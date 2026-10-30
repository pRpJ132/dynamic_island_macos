import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

enum IslandState { collapsed, expanded }

enum StateScreen {
  main,
  mainMusic,
  music,
  musicPlaylists,
  app,
  search,
}

class MainAppController extends ChangeNotifier {
  bool hideApp = false;
  bool clickThrough = false;
  Timer? _hoverPollTimer;
  late StreamSubscription _sub;
  late Battery battery;
  ValueNotifier<int?> batteryLevel = ValueNotifier(null);

  Map<StateScreen, SizeWindowObject> sizeWindowObjects = {
    StateScreen.main: SizeWindowObject(
      collapsedSize: Size(260, 80),
      collapsedSizeBaseDynamicIsland: Size(420, 75)
    ),
    StateScreen.music: SizeWindowObject(
      collapsedSizeBaseDynamicIsland: Size(420, 48),
      expandedSize: Size(360, 290),
      expandedSizeBaseDynamicIsland: Size(420, 270),
    ),
    StateScreen.app: SizeWindowObject(
      collapsedSize: Size(420, 95),
      expandedSize: Size(420, 170),
      collapsedSizeBaseDynamicIsland: Size(420, 95),
      expandedSizeBaseDynamicIsland: Size(420, 170),
    ),
    StateScreen.search: SizeWindowObject(
      collapsedSize: Size(320, 50),
      expandedSize: Size(420, 310),
      collapsedSizeBaseDynamicIsland: Size(420, 75),
      expandedSizeBaseDynamicIsland: Size(420, 310),
    ),

    StateScreen.mainMusic: SizeWindowObject(
      collapsedSize: Size(400, 80),
      expandedSize: Size(400, 170),
      collapsedSizeBaseDynamicIsland: Size(420, 75),
    ),
    StateScreen.musicPlaylists: SizeWindowObject(
      collapsedSizeBaseDynamicIsland: Size(420, 48),
      expandedSize: Size(360, 390),
      expandedSizeBaseDynamicIsland: Size(420, 470),
    ),
  };

  bool _animatedChangeDynamicIsland = false;
  bool get animatedChangeDynamicIsland => _animatedChangeDynamicIsland;
  set animatedChangeDynamicIsland(bool v) {
    _animatedChangeDynamicIsland = v;
    notifyListeners();
  }

  StateScreen _stateScreen = StateScreen.main;
  StateScreen get stateScreen => _stateScreen;
  set stateScreen(StateScreen ss) {
    if (ss == StateScreen.main && MusicService().isPlayingMusic) {
      _stateScreen = StateScreen.mainMusic;
      return;
    }
    _stateScreen = ss;
  }

  SizeWindowObject _sizeWindow = SizeWindowObject();
  SizeWindowObject get sizeWindow => _sizeWindow;
  set sizeWindow(SizeWindowObject? swo) {
    _sizeWindow = swo ?? SizeWindowObject();
  }

  IslandState _stateApp = IslandState.collapsed;
  IslandState get stateApp => _stateApp;
  bool get isExpanded =>  _stateApp == IslandState.expanded;
  set stateApp(IslandState newState) {
    _stateApp = newState;
    notifyListeners();
  }

  bool _isDynamicIsland = false;
  bool get isDynamicIsland => _isDynamicIsland;
  set isDynamicIsland(bool v) {
    if (v) {
      _hoverPollTimer?.cancel();
      _hoverPollTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _pollMousePosition(),
      );
    } else {
      _hoverPollTimer?.cancel();
      _hoverPollTimer = null;
    }

    _isDynamicIsland = v;
    notifyListeners();
  }

  MainAppController() {
    if (Platform.isMacOS) {
      battery = Battery();
      _sub = Stream.periodic(const Duration(seconds: 1)).listen((_) async {
        final level = await battery.batteryLevel;
        batteryLevel.value = level;
      });
    }
  }

  @override
  void dispose() {
    _hoverPollTimer?.cancel();
    _sub.cancel();
    batteryLevel.dispose();
    super.dispose();
  }

  IslandState _targetState = IslandState.collapsed;
  bool isAnimating = false;

  bool _mouseInside = false;
  static const _channel = MethodChannel('window/animation');

  Future<void> _pollMousePosition() async {
    if (!isDynamicIsland || isAnimating || _animatedChangeDynamicIsland || hideApp) return;
    try {
      _mouseInside = await _channel.invokeMethod<bool>('isMouseInsideWindow') ?? false;
    } catch (_) {
    }

    if (!clickThrough) {
      requestState(newState: _mouseInside ? IslandState.expanded : IslandState.collapsed);
    } else if (!hideApp) {
      _mouseInside ? windowManager.hide() : windowManager.show();
    }
  }

  Future<void> requestState({IslandState? newState, bool waitResized = false}) async {
    _targetState = newState ?? (stateApp == IslandState.expanded ? IslandState.collapsed : IslandState.expanded);
    if (isAnimating || stateApp == _targetState) return;

    isAnimating = true;
    final animatingTo = _targetState;

    stateApp = animatingTo;
    final size = animatingTo == IslandState.expanded
        ? isDynamicIsland ? _sizeWindow.expandedSizeBaseDynamicIsland : _sizeWindow.expandedSize
        : isDynamicIsland ? _sizeWindow.collapsedSizeBaseDynamicIsland : _sizeWindow.collapsedSize;

    try {
      waitResized ? await resizeWindow(size) : resizeWindow(size);
    } catch (_) {}
    isAnimating = false;

    // final correctTarget = _mouseInside ? IslandState.expanded : IslandState.collapsed;
    // if (stateApp != correctTarget && isDynamicIsland) {
    //   _targetState = correctTarget;
    //   waitResized ? await requestState(newState: _targetState, waitResized: waitResized) 
    //   : requestState(newState: _targetState, waitResized: waitResized);
    // }
  }

  Future<void> resizeWindow(Size size, {String? curve, double? duration}) async {
    await _channel.invokeMethod('resize', {
      'width': size.width,
      'height': size.height,
      'duration': duration ?? 1.6,
      'curve': curve ?? 'easeInOut',
    });
  }

  void hidenApp() {
    hideApp = !hideApp;
    if (hideApp) {
      windowManager.hide();
      requestState(newState: IslandState.collapsed);
    } else {
      windowManager.show();
    }
  }
}

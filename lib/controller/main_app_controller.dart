import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/service/musci_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

enum IslandState { collapsed, expanded }

enum StateScreen { main, mainMusic, music, app}

class MainAppController extends ChangeNotifier {
  bool hideApp = false;
  bool clickThrough = false;
  bool activatedHide = false;
  Timer? _hoverPollTimer;
  late StreamSubscription _sub;
  late Battery battery;
  ValueNotifier<int?> batteryLevel = ValueNotifier(null);

  bool _animatedChangeDynamicIsland = false;
  bool get animatedChangeDynamicIsland => _animatedChangeDynamicIsland;
  set animatedChangeDynamicIsland(bool v) {
    _animatedChangeDynamicIsland = v;
    notifyListeners();
  }

  StateScreen _stateScreen = StateScreen.main;
  StateScreen get stateScreen => _stateScreen;
  set stateScreen(StateScreen ss) {
    if (ss == StateScreen.main && MusicService().isPlayingMusic.value) {
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
    battery = Battery();
    _sub = Stream.periodic(const Duration(seconds: 1)).listen((_) async {
      final level = await battery.batteryLevel;
      batteryLevel.value = level;
    });
  }

  @override
  void dispose() {
    _hoverPollTimer?.cancel();
    _sub.cancel();
    batteryLevel.dispose();
    super.dispose();
  }

  IslandState _targetState = IslandState.collapsed;
  bool _isAnimating = false;
  bool get isAnimating => _isAnimating;
  set isAnimating(bool v) {
    _isAnimating = v;
    notifyListeners();
  }

  bool _mouseInside = false;
  static const _channel = MethodChannel('window/animation');

  Future<void> _pollMousePosition() async {
    if (!isDynamicIsland || _isAnimating || _animatedChangeDynamicIsland || activatedHide) return;
    bool inside = false;
    try {
      inside = await _channel.invokeMethod<bool>('isMouseInsideWindow') ?? false;
    } catch (_) {
    }

    if (inside == _mouseInside) return;

    _mouseInside = inside;
    if (!clickThrough) {
      _requestState(inside ? IslandState.expanded : IslandState.collapsed);
    } else{
      !_mouseInside ? hidenApp(hiden: true) : hidenApp(hiden: false);
    }
  }

  void _requestState(IslandState newState) {
    _targetState = newState;
    if (isAnimating) return;
    if (stateApp == _targetState) return;

    isAnimating = true;
    final animatingTo = _targetState;

    stateApp = animatingTo;

    final size = animatingTo == IslandState.expanded
        ? isDynamicIsland ? _sizeWindow.expandedSizeBaseDynamicIsland : _sizeWindow.expandedSize
        : isDynamicIsland ? _sizeWindow.collapsedSizeBaseDynamicIsland : _sizeWindow.collapsedSize;

    try {
      resizeWindow(size);
    } catch (_) {}

    isAnimating = false;

    final correctTarget = _mouseInside ? IslandState.expanded : IslandState.collapsed;
    if (stateApp != correctTarget && isDynamicIsland) {
      _targetState = correctTarget;
      _requestState(_targetState);
    }
  }

  Future<void> requestState(IslandState newState) async {
    _targetState = newState;
    if (isAnimating) return;
    if (stateApp == _targetState) return;

    isAnimating = true;
    final animatingTo = _targetState;

    stateApp = animatingTo;

    final size = animatingTo == IslandState.expanded
        ? isDynamicIsland ? _sizeWindow.expandedSizeBaseDynamicIsland : _sizeWindow.expandedSize
        : isDynamicIsland ? _sizeWindow.collapsedSizeBaseDynamicIsland : _sizeWindow.collapsedSize;

    try {
      await resizeWindow(size);
    } catch (_) {}

    isAnimating = false;
  }

  Future<void> resizeWindow(Size size, {String? curve, double? duration}) async {
    await _channel.invokeMethod('resize', {
      'width': size.width,
      'height': size.height,
      'duration': duration ?? 1.6,
      'curve': curve ?? 'easeInOut',
    });
  }

  Future<void> hidenApp({final bool? hiden}) async {
    if (activatedHide) {
      await windowManager.hide();
      hideApp = true;
      return;
    }

    if (hiden ?? hideApp) {
      await windowManager.show();
      await windowManager.focus();
      hideApp = false;
    } else {
      await windowManager.hide();
      hideApp = true;
    }
  }
}

import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum IslandState { collapsed, expanded }

class MainAppController extends ChangeNotifier {
  bool hideApp = false;
  bool clickThrough = false;
  SizeWindowObject sizeWindow = SizeWindowObject();
  Timer? _hoverPollTimer;
  Battery? battery;
  ValueNotifier<int> batteryLevel = ValueNotifier(100);

  bool _animatedChangeDynamicIsland = false;
  bool get animatedChangeDynamicIsland => _animatedChangeDynamicIsland;
  set animatedChangeDynamicIsland(bool v) {
    _animatedChangeDynamicIsland = v;
    notifyListeners();
  }

  IslandState _stateApp = IslandState.collapsed;
  IslandState get stateApp => _stateApp;
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

  late StreamSubscription _sub;
  MainAppController() {
    battery = Battery();
    _sub = Stream.periodic(const Duration(seconds: 1)).listen((_) async {
      final level = await battery!.batteryLevel;
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
    if (!isDynamicIsland || _isAnimating || _animatedChangeDynamicIsland) return;
    bool inside = false;
    try {
      inside = await _channel.invokeMethod<bool>('isMouseInsideWindow') ?? false;
    } catch (_) {
    }

    if (inside == _mouseInside) return;

    _mouseInside = inside;
    _requestState(inside ? IslandState.expanded : IslandState.collapsed);
  }

  void _requestState(IslandState newState) {
    _targetState = newState;
    if (isAnimating) return;
    if (stateApp == _targetState) return;

    isAnimating = true;
    final animatingTo = _targetState;

    stateApp = animatingTo;

    final size = animatingTo == IslandState.expanded
        ? isDynamicIsland ? sizeWindow.expandedSizeBaseDynamicIsland : sizeWindow.expandedSize
        : isDynamicIsland ? sizeWindow.collapsedSizeBaseDynamicIsland : sizeWindow.collapsedSize;

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
        ? isDynamicIsland ? sizeWindow.expandedSizeBaseDynamicIsland : sizeWindow.expandedSize
        : isDynamicIsland ? sizeWindow.collapsedSizeBaseDynamicIsland : sizeWindow.collapsedSize;

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
}

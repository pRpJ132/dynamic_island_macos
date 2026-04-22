import 'dart:async';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum IslandState { collapsed, expanded }

class MainAppController extends ChangeNotifier {
  bool hideApp = false;
  bool clickThrough = false;
  bool _isDynamicIsland = false;
  IslandState _stateApp = IslandState.collapsed;
  SizeWindowObject sizeWindow = SizeWindowObject();
  Timer? _hoverPollTimer;


  IslandState get stateApp => _stateApp;
  set stateApp(IslandState newState) {
    _stateApp = newState;
    notifyListeners();
  }

  bool get isDynamicIsland => _isDynamicIsland;
  set isDynamicIsland(bool v) {
    if (v) {
      _hoverPollTimer?.cancel();
      _hoverPollTimer = Timer.periodic(
        const Duration(milliseconds: 30),
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
    if (_isDynamicIsland) {
      _hoverPollTimer = Timer.periodic(
        const Duration(milliseconds: 30),
        (_) => _pollMousePosition(),
      );
    }
  }
  IslandState _targetState = IslandState.collapsed;
  bool _isAnimating = false;
  bool _mouseInside = false;
  static const _channel = MethodChannel('window/animation');

  Future<void> _pollMousePosition() async {
    if (!isDynamicIsland) return;
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
    if (!isDynamicIsland) return;
    _targetState = newState;
    _applyTargetState();
  }

  Future<void> _applyTargetState() async {
    if (_isAnimating) return;
    if (stateApp == _targetState) return;
    if (!isDynamicIsland) return;

    _isAnimating = true;
    final animatingTo = _targetState;

    stateApp = animatingTo;

    final size = animatingTo == IslandState.expanded
        ? sizeWindow.expandedSizeBaseDynamicIsland
        : sizeWindow.collapsedSizeBaseDynamicIsland;

    try {
      await _channel.invokeMethod('resize', {
        'width': size.width,
        'height': size.height,
        'duration': 0.2,
        'curve': 'easeInOut',
      });
    } catch (_) {}

    _isAnimating = false;

    final correctTarget =
        _mouseInside ? IslandState.expanded : IslandState.collapsed;
    if (stateApp != correctTarget) {
      _targetState = correctTarget;
      _applyTargetState();
    }
  }
}

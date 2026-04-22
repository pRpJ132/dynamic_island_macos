import 'dart:async';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

enum IslandState { collapsed, expanded }

class DynamicIslandTime extends StatefulWidget {
  const DynamicIslandTime({super.key});

  @override
  State<DynamicIslandTime> createState() => _DynamicIslandTimeState();
}

class _DynamicIslandTimeState extends State<DynamicIslandTime> {
  static const _channel = MethodChannel('window/animation');

  final ValueNotifier<IslandState> _state = ValueNotifier(IslandState.collapsed);
  IslandState _targetState = IslandState.collapsed;

  bool _isAnimating = false;
  bool _mouseInside = false;

  Timer? _debounceTimer;
  late Timer _clockTimer;

  final ValueNotifier<String> _time = ValueNotifier("");
  final mainAppController = MainAppController();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    _time.value = DateFormat('HH:mm:ss').format(DateTime.now());
  }

  void _onEnter() {
    _mouseInside = true;
    _requestState(IslandState.expanded);
  }

  void _onExit() {
    _mouseInside = false;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 80), () {
      if (!_mouseInside) {
        _requestState(IslandState.collapsed);
      }
    });
  }

  void _requestState(IslandState newState) {
    if (newState == IslandState.expanded) {
      _targetState = newState;
      _debounceTimer?.cancel();
      _applyTargetState();
    } else {
      _targetState = newState;
      _applyTargetState();
    }
  }

  Future<void> _applyTargetState() async {
    if (_isAnimating) return;
    if (_state.value == _targetState) return;

    _isAnimating = true;
    final animatingTo = _targetState;

    _state.value = animatingTo;

    final size = animatingTo == IslandState.expanded ? mainAppController.expandedSizeBase : mainAppController.collapsedSizeBase;

    try {
      await _channel.invokeMethod('resize', {
        'width': size.width,
        'height': size.height,
        'duration': 0.2,
        'curve': 'easeInOut',
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 370));

    _isAnimating = false;
    final shouldBeExpanded = _mouseInside;
    final correctTarget = shouldBeExpanded ? IslandState.expanded : IslandState.collapsed;

    if (_state.value != correctTarget) {
      _targetState = correctTarget;
      _applyTargetState();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _clockTimer.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) async => await windowManager.startDragging(),
      child: MouseRegion(
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SizedBox(
              width: mainAppController.collapsedSizeBase.width,
              height: mainAppController.collapsedSizeBase.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.black,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ...previousChildren,
                          ?currentChild,
                        ],
                      );
                    },
                    child: ValueListenableBuilder(
                      valueListenable: _state, 
                      builder: (_, stateValue, _) => stateValue == IslandState.expanded
                        ? _ExpandedView(time: _time)
                        : _CollapsedView(time: _time),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final ValueNotifier<String> time;
  const _ExpandedView({required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey("expanded"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Dynamic Island",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        ValueListenableBuilder(
          valueListenable: time,
          builder: (_, value, __) {
            return Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 22,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CollapsedView extends StatelessWidget {
  final ValueNotifier<String> time;
  const _CollapsedView({required this.time});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      key: const ValueKey("collapsed"),
      valueListenable: time,
      builder: (_, value, __) {
        return Text(
          value.substring(0, 5),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1,
          ),
        );
      },
    );
  }
}
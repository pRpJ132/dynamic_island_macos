import 'dart:async';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DynamicIslandTime extends StatefulWidget {
  const DynamicIslandTime({super.key});

  @override
  State<DynamicIslandTime> createState() => _DynamicIslandTimeState();
}

class _DynamicIslandTimeState extends State<DynamicIslandTime> {
  late Timer _clockTimer;
  final ValueNotifier<String> _time = ValueNotifier("");
  final sizeWindow = SizeWindowObject();

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
    _time.value = DateFormat('HH:mm:ss').format(DateTime.now());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Consumer<MainAppController>(
          builder: (_, mainAppController, _) =>
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: mainAppController.isDynamicIsland ? Colors.black : Colors.transparent,
              ),
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  scale: mainAppController.stateApp == IslandState.expanded ? 1.3 : 1,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    child: mainAppController.stateApp == IslandState.expanded
                        ? _ExpandedView(time: _time)
                        : _CollapsedView(time: _time),
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
        Flexible(
          child: const Text(
            "Dynamic Island",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        ValueListenableBuilder(
          valueListenable: time,
          builder: (_, value, _) {
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
      builder: (_, value, _) {
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
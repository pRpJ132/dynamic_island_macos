import 'dart:async';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
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
    _time.value = DateFormat('HH:mm:ss │ yyyy.MM.dd').format(DateTime.now());
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
      builder: (_, controller, _) {
        final isExpanded = controller.stateApp == IslandState.expanded;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: isExpanded ? 0 : 18,
          ),
          child: ValueListenableBuilder<String>(
            valueListenable: _time,
            builder: (_, value, _) {
              return AnimatedAlign(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                alignment: isExpanded
                    ? Alignment.center
                    : Alignment.bottomCenter,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    color: Colors.white.withOpacity(
                      isExpanded ? 0.9 : 1,
                    ),
                    fontSize: isExpanded ? 28 : 14,
                    fontWeight: isExpanded
                        ? FontWeight.w300
                        : FontWeight.w400,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
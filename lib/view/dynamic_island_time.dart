import 'dart:async';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/models/size_window_object.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ultimate_flutter_icons/flutter_icons.dart';

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
    return SizedBox.expand(
      child: Consumer<MainAppController>(
        builder: (_, mainAppController, _) => ClipPath(
          clipper: mainAppController.isDynamicIsland ? ConcaveCornersClipper() : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 350),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: (mainAppController.isDynamicIsland && mainAppController.stateApp != IslandState.expanded) ? 24 : 20),
            decoration: BoxDecoration(
              color: mainAppController.isDynamicIsland ? Colors.black : Colors.transparent,
            ),
            child: Stack(
              children: [
                if (mainAppController.isDynamicIsland)
                AnimatedPositioned(
                  curve: Curves.easeOutBack,
                  duration: Duration(milliseconds: 850),
                  left: (mainAppController.isDynamicIsland && mainAppController.stateApp != IslandState.expanded) ? 3 : 10,
                  top: (mainAppController.isDynamicIsland && mainAppController.stateApp != IslandState.expanded) ? 20 : 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle
                    ),
                  )
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  child: mainAppController.stateApp == IslandState.expanded
                      ? _ExpandedView(time: _time, mainAppController: mainAppController)
                      : _CollapsedView(time: _time, mainAppController: mainAppController),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final ValueNotifier<String> time;
  final MainAppController mainAppController;
  const _ExpandedView({required this.time, required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: const Text(
              "Dynamic Island TEsT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: time,
            builder: (_, value, _) {
              return Text(
                value,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CollapsedView extends StatelessWidget {
  final ValueNotifier<String> time;
  final MainAppController mainAppController;
  const _CollapsedView({required this.time, required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Row(
        mainAxisAlignment: mainAppController.isDynamicIsland ? .end : .center,
        spacing: 5,
        children: [
          ValueListenableBuilder(
            valueListenable: time,
            builder: (_, value, _) {
              return Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1,
                ),
              );
            },
          ),
          FIcon(
            GO.GoClockFill,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:ultimate_flutter_icons/flutter_icons.dart';

class DynamicIslandTimer extends StatefulWidget {
  const DynamicIslandTimer({super.key});

  @override
  State<DynamicIslandTimer> createState() => _DynamicIslandTimerState();
}

class _DynamicIslandTimerState extends State<DynamicIslandTimer> {
  final ValueNotifier<int> stopwatch = ValueNotifier(0);

  final ValueNotifier<int> timer = ValueNotifier(60);

  final ValueNotifier<bool> isRunning = ValueNotifier(false);
  final ValueNotifier<bool> isTimerMode = ValueNotifier(false);

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();

    _ticker = Ticker((elapsed) {
      if (isRunning.value) {
        if (isTimerMode.value) {
          if (timer.value > 0) {
            timer.value -= 1;
          }
        } else {
          stopwatch.value += 1000;
        }
      }
    });

    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    stopwatch.dispose();
    timer.dispose();
    isRunning.dispose();
    isTimerMode.dispose();
    super.dispose();
  }

  String formatTime(int ms) {
    final seconds = ms ~/ 1000;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
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
                      ? _ExpandedView(mainAppController: mainAppController)
                      : _CollapsedView(mainAppController: mainAppController),
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
  final MainAppController mainAppController;
  const _ExpandedView({required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_DynamicIslandTimerState>()!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: ValueListenableBuilder<bool>(
            valueListenable: state.isTimerMode,
            builder: (_, isTimer, _) => GestureDetector(
              onTap: () => state.isTimerMode.value = !isTimer,
              child: Text(
                isTimer ? "Таймер" : "Секундомер",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
    
        const SizedBox(height: 8),
    
        Flexible(
          child: ValueListenableBuilder(
            valueListenable: state.isTimerMode,
            builder: (_, isTimer, _) {
              return ValueListenableBuilder<int>(
                valueListenable: isTimer ? state.timer : state.stopwatch,
                builder: (_, value, _) => Text(
                  isTimer
                      ? "${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}"
                      : state.formatTime(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                   ),
                ),
              );
            },
          ),
        ),
    
        const SizedBox(height: 10),
    
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: state.isRunning,
                builder: (_, running, _) => IconButton(
                  icon: Icon(
                    running ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    state.isRunning.value = !running;
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  state.stopwatch.value = 0;
                  state.timer.value = 60;
                  state.isRunning.value = false;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollapsedView extends StatelessWidget {
  final MainAppController mainAppController;
  const _CollapsedView({required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_DynamicIslandTimerState>()!;
    return SizedBox.expand(
      child: Row(
        mainAxisAlignment: mainAppController.isDynamicIsland ? .end : .center,
        spacing: 5,
        children: [
          ValueListenableBuilder(
            valueListenable: state.isTimerMode,
            builder: (_, isTimer, _) {
              return ValueListenableBuilder<int>(
                valueListenable: isTimer ? state.timer : state.stopwatch,
                builder: (_, value, _) => Text(
                  isTimer
                      ? "${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}"
                      : state.formatTime(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
      
          const SizedBox(height: 10),
          FIcon(
            BS.BsFillStopwatchFill,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}
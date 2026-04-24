import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';

class DynamicIslandBattery extends StatefulWidget {
  final MainAppController mainAppController;
  const DynamicIslandBattery({
    super.key,
    required this.mainAppController,
  });

  @override
  State<DynamicIslandBattery> createState() => _DynamicIslandBatteryState();
}

class _DynamicIslandBatteryState extends State<DynamicIslandBattery> {
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Consumer<MainAppController>(
        builder: (_, controller, _) => ClipPath(
          clipper: controller.isDynamicIsland ? ConcaveCornersClipper() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: controller.isDynamicIsland ? Colors.black : Colors.transparent,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: controller.stateApp == IslandState.expanded
                    ? _ExpandedBattery(batteryLevel: widget.mainAppController.batteryLevel, mainAppController: widget.mainAppController,)
                    : _CollapsedBattery(batteryLevel: widget.mainAppController.batteryLevel, mainAppController: widget.mainAppController,),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedBattery extends StatelessWidget {
  final ValueNotifier<int> batteryLevel;
  final MainAppController mainAppController;
  const _CollapsedBattery({required this.batteryLevel, required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: batteryLevel,
      builder: (_, level, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _BatteryIcon(level: level, mainAppController: mainAppController,)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$level%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandedBattery extends StatelessWidget {
  final ValueNotifier<int> batteryLevel;
  final MainAppController mainAppController;
  const _ExpandedBattery({required this.batteryLevel, required this.mainAppController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: batteryLevel,
      builder: (_, level, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _BatteryIcon(level: level, mainAppController: mainAppController,)),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                '$level%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BatteryIcon extends StatefulWidget {
  final int level;
  final MainAppController mainAppController;

  const _BatteryIcon({
    required this.level,
    required this.mainAppController,
  });

  @override
  State<_BatteryIcon> createState() => _BatteryIconState();
}

class _BatteryIconState extends State<_BatteryIcon> {
  static BatteryState? _batteryState;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final battery = widget.mainAppController.battery;

    _sub = battery?.onBatteryStateChanged.listen((state) {
      setState(() {
        _batteryState = state;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color get _fillColor {
    final isCharging = _batteryState == BatteryState.charging;

    if (widget.level <= 20) {
      return isCharging
          ? const Color(0xFFFF4D4D)
          : Colors.red;
    }

    if (widget.level <= 40) {
      return isCharging
          ? const Color(0xFFFFD24D)
          : Colors.amber;
    }

    return isCharging
        ? const Color(0xFF00FF6A)
        : const Color(0xFF43B146);
  }

  @override
  Widget build(BuildContext context) {
    final double width = 38;
    final double height = 19;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: AlignmentGeometry.center,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.all(2),
              child: FractionallySizedBox(
                widthFactor: widget.level / 100,
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _fillColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _batteryState == BatteryState.charging ? 1 : 0,
              duration: Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              child: Icon(
                CupertinoIcons.bolt_fill,
                color: Colors.white,
                size: 16,
              )
            ),
          ],
        ),
        // Кончик батареи
        Container(
          width: 3,
          height: height * 0.4,
          decoration: const BoxDecoration(
            color: Colors.white38,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
          ),
        ),
      ],
    );
  }
}
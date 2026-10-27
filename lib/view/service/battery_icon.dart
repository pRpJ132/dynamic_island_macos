import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BatteryIcon extends StatefulWidget {
  final int level;
  final double width;
  final double height;
  final double border;
  final MainAppController? mainAppController;

  const BatteryIcon({super.key, 
    required this.width,
    required this.height,
    required this.level,
    required this.mainAppController, 
    required  this.border,
  });

  @override
  State<BatteryIcon> createState() => _BatteryIconState();
}

class _BatteryIconState extends State<BatteryIcon> {
  static BatteryState? _batteryState;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    Battery? battery = widget.mainAppController?.battery;

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: AlignmentGeometry.center,
          children: [
            AnimatedContainer(
              curve: Curves.easeInOut,
              duration: Duration(milliseconds: 500),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 0.5),
                borderRadius: BorderRadius.circular(widget.border+2),
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
                    borderRadius: BorderRadius.circular(widget.border),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _batteryState == BatteryState.charging ? 1 : 0,
              duration: Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              child: AnimatedScale(
                duration: Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                scale: widget.mainAppController?.stateApp == IslandState.expanded ? 2.4 : 1,
                child: Icon(
                  CupertinoIcons.bolt_fill,
                  color: Colors.white,
                  size: 12,
                ),
              )
            ),
          ],
        ),
        AnimatedContainer(
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 500),
          width: 3,
          height: widget.height * 0.4,
          decoration: BoxDecoration(
            color: Colors.white38,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(widget.border - 1)),
          ),
        ),
      ],
    );
  }
}
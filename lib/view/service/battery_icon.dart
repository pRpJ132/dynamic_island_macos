import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BatteryIcon extends StatefulWidget {
  final double width;
  final double height;
  final double border;
  final MainAppController mainAppController;

  const BatteryIcon({super.key, 
    required this.width,
    required this.height,
    required this.mainAppController, 
    required  this.border,
  });

  @override
  State<BatteryIcon> createState() => _BatteryIconState();
}

class _BatteryIconState extends State<BatteryIcon> {
  StreamSubscription? _subBatteryStateChanged;
  late Battery _battery;
  ValueNotifier<bool> isCharging = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _battery = widget.mainAppController.battery;

    _subBatteryStateChanged = _battery.onBatteryStateChanged.listen((state) {
      isCharging.value = state == BatteryState.charging || state == BatteryState.connectedNotCharging;
    });
  }

  @override
  void dispose() {
    _subBatteryStateChanged?.cancel();
    super.dispose();
  }

  Color _fillColor(int? level) {
    if (level == null) {
      return Colors.blueGrey;
    }

    if (level <= 20) {
      return isCharging.value
          ? const Color.fromARGB(255, 217, 72, 72)
          : Colors.red;
    }

    if (level <= 40) {
      return isCharging.value
          ? const Color.fromARGB(255, 255, 210, 77)
          : const Color.fromARGB(255, 255, 193, 7);
    }

    return isCharging.value
        ? const Color.fromARGB(255, 0, 255, 106)
        : const Color.fromARGB(255, 67, 177, 70);
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
              child: ValueListenableBuilder<int?>(
                valueListenable: widget.mainAppController.batteryLevel,
                builder: (context, level, child) {
                  return FractionallySizedBox(
                    widthFactor: level != null ? level / 100 : 0,
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: _fillColor(level),
                        borderRadius: BorderRadius.circular(widget.border),
                      ),
                    ),
                  );
                }
              ),
            ),
            ValueListenableBuilder(
              valueListenable: isCharging,
              builder: (_, value, _) {
                return AnimatedOpacity(
                  opacity: value ? 1 : 0,
                  duration: Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    CupertinoIcons.bolt_fill,
                    color: Colors.white,
                    size: 12,
                  )
                );
              }
            ),
          ],
        ),
        AnimatedContainer(
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 500),
          width: 2.4,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white38,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(widget.border - 1)),
          ),
        ),
      ],
    );
  }
}
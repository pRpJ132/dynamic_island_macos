import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/shape/concave_corners_clipper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ultimate_flutter_icons/flutter_icons.dart';

class DynamicIslandDropFile extends StatefulWidget {
  const DynamicIslandDropFile({super.key});

  @override
  State<DynamicIslandDropFile> createState() => _DynamicIslandDropFileState();
}

class _DynamicIslandDropFileState extends State<DynamicIslandDropFile> {
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
                  child: _ExpandedView(mainAppController: mainAppController)
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
    return SizedBox.expand(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FIcon(
              RI.RiDragDropLine,
              size: 75,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
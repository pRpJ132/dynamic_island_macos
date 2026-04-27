import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
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
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) => AnimatedSwitcher(
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
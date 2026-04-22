import 'package:flutter/material.dart';

class MainAppController with ChangeNotifier {
  bool hideApp = false;
  bool clickThrough = false;
  final Size collapsedSizeBase = const Size(160, 50);
  final Size expandedSizeBase  = const Size(340, 120);
}



import 'dart:ui';

class SizeWindowObject {
  final Size collapsedSize = const Size(160, 50);
  final Size expandedSize;
  final Size collapsedSizeBaseDynamicIsland = const Size(420, 45);
  final Size expandedSizeBaseDynamicIsland;

  const SizeWindowObject({
    this.expandedSize = const Size(340, 120),
    this.expandedSizeBaseDynamicIsland = const Size(400, 155),
  });
}
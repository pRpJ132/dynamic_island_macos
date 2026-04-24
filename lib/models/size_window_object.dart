import 'dart:ui';

class SizeWindowObject {
  final Size collapsedSize;
  final Size expandedSize;
  final Size collapsedSizeBaseDynamicIsland;
  final Size expandedSizeBaseDynamicIsland;

  const SizeWindowObject({
    this.collapsedSize = const Size(160, 50),
    this.expandedSize = const Size(340, 120),
    this.collapsedSizeBaseDynamicIsland = const Size(420, 45),
    this.expandedSizeBaseDynamicIsland = const Size(420, 170),
  });
}
import 'dart:ui';

class SizeWindowObject {
  final Size collapsedSize;
  final Size expandedSize;
  final Size collapsedSizeBaseDynamicIsland = const Size(180, 31);
  final Size expandedSizeBaseDynamicIsland;

  const SizeWindowObject({
    this.collapsedSize = const Size(160, 50),
    this.expandedSize = const Size(340, 120),
    this.expandedSizeBaseDynamicIsland = const Size(400, 155),
  });
}
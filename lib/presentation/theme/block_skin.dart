import 'dart:ui';

/// Draws one block into the given rectangle. Atomic visual unit.
abstract class BlockSkin {
  /// Paints a block skin into [rect].
  ///
  /// [boardX] and [boardY] are optional board cell coordinates used for
  /// deterministic procedural noise.
  void paint(
    Canvas canvas,
    Rect rect, {
    int? boardX,
    int? boardY,
  });
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'block_paint_utils.dart';
import 'block_skin.dart';

/// Draws a block texture from a PNG asset image.
class ImageBlockSkin implements BlockSkin {
  /// Creates an image-based block skin.
  const ImageBlockSkin(this.image);

  /// The source image to draw.
  final ui.Image image;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    int? boardX,
    int? boardY,
  }) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, rect, Paint());
    BlockPaintUtils.drawBevel(canvas, rect);
    BlockPaintUtils.drawBlockOutline(canvas, rect);
  }
}

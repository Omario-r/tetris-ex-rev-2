import 'dart:ui';

import 'package:flutter/material.dart';

import 'block_material.dart';
import 'block_paint_utils.dart';
import 'block_skin.dart';

/// Procedural placeholder skin that draws a material texture in code.
class ProceduralBlockSkin implements BlockSkin {
  /// Creates a procedural skin for the given [material].
  const ProceduralBlockSkin(this.material);

  /// The block material this skin renders.
  final BlockMaterial material;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    int? boardX,
    int? boardY,
  }) {
    final bx = boardX ?? 0;
    final by = boardY ?? 0;
    BlockPaintUtils.paintBlock(
      canvas,
      rect,
      bx,
      by,
      (lx, ly) => _colorAt(material, bx, by, lx, ly),
    );
  }

  static Color _colorAt(
    BlockMaterial material,
    int boardX,
    int boardY,
    int localX,
    int localY,
  ) {
    return switch (material) {
      BlockMaterial.grass => _grassColor(boardX, boardY, localX, localY),
      BlockMaterial.dirt => _dirtColor(boardX, boardY, localX, localY),
      BlockMaterial.cobble => _cobbleColor(boardX, boardY, localX, localY),
      BlockMaterial.planks => _planksColor(boardX, boardY, localX, localY),
      BlockMaterial.bricks => _bricksColor(boardX, boardY, localX, localY),
      BlockMaterial.sand => _sandColor(boardX, boardY, localX, localY),
      BlockMaterial.stone => _stoneColor(boardX, boardY, localX, localY),
    };
  }

  static Color _grassColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    if (ly < 3) {
      return BlockPaintUtils.pick(
        v,
        [0.0, 0.33, 0.66],
        [
          const Color(0xFF6BA832),
          const Color(0xFF7BBE3A),
          const Color(0xFF8FD14A),
        ],
      );
    }
    if (ly == 3) {
      return const Color(0xFF8A6B45);
    }
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF795C3A),
        const Color(0xFF8A6B45),
        const Color(0xFF9A7A52),
      ],
    );
  }

  static Color _dirtColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF795C3A),
        const Color(0xFF8A6B45),
        const Color(0xFF9A7A52),
      ],
    );
  }

  static Color _cobbleColor(int bx, int by, int lx, int ly) {
    if (lx % 4 == 0 && ly % 4 == 0) {
      return const Color(0xFF3F3C37);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.25, 0.5, 0.75],
      [
        const Color(0xFF6B685F),
        const Color(0xFF7D7A72),
        const Color(0xFF8F8C83),
        const Color(0xFFA3A097),
      ],
    );
  }

  static Color _planksColor(int bx, int by, int lx, int ly) {
    if (ly % 5 == 4) {
      return const Color(0xFF7C5A2F);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    if (v > 0.85) {
      return const Color(0xFFA9783E);
    }
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFFB07F42),
        const Color(0xFFBD8A4A),
        const Color(0xFFC99A58),
      ],
    );
  }

  static Color _bricksColor(int bx, int by, int lx, int ly) {
    final row = ly ~/ 4;
    final offset = (row % 2) * 2;
    final inMortar = ly % 4 == 0 || (lx + offset) % 4 == 0;
    if (inMortar) {
      return const Color(0xFFB7A89A);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF8A3C2F),
        const Color(0xFF9E4636),
        const Color(0xFFB2503C),
      ],
    );
  }

  static Color _sandColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFFD6C184),
        const Color(0xFFE4D29A),
        const Color(0xFFEFE0AD),
      ],
    );
  }

  static Color _stoneColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF7C7972),
        const Color(0xFF8B8880),
        const Color(0xFF98958C),
      ],
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import 'block_material.dart';
import 'block_paint_utils.dart';
import 'block_skin.dart';

/// Procedural placeholder skin that draws a material texture in code.
///
/// Colors follow the "Ronin" ship reference palette (`ship_ronin_v4.html`):
/// graphite / graphite-dark / dark niche / hazard orange / rust / gunmetal /
/// matte black. Shades used here are lightness variants of the reference
/// hues only — no invented colors.
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
      BlockMaterial.graphite =>
        _graphiteColor(boardX, boardY, localX, localY),
      BlockMaterial.graphiteDark =>
        _graphiteDarkColor(boardX, boardY, localX, localY),
      BlockMaterial.darkNiche =>
        _darkNicheColor(boardX, boardY, localX, localY),
      BlockMaterial.hazardOrange =>
        _hazardOrangeColor(boardX, boardY, localX, localY),
      BlockMaterial.rust => _rustColor(boardX, boardY, localX, localY),
      BlockMaterial.gunmetal => _gunmetalColor(boardX, boardY, localX, localY),
      BlockMaterial.matteBlack =>
        _matteBlackColor(boardX, boardY, localX, localY),
    };
  }

  /// GRAF hsl(215,9%,31%) family — smooth mid-tone plate.
  static Color _graphiteColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF3A3F45),
        const Color(0xFF484E56),
        const Color(0xFF565D67),
      ],
    );
  }

  /// GRAF2 hsl(215,9%,26%) family — darker plate with corner rivets.
  static Color _graphiteDarkColor(int bx, int by, int lx, int ly) {
    if (lx % 4 == 0 && ly % 4 == 0) {
      return const Color(0xFF1D2025);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF2E3238),
        const Color(0xFF3C4148),
        const Color(0xFF4A5059),
      ],
    );
  }

  /// DARK hsl(216,11%,17%) family — recessed niche with inset seams.
  static Color _darkNicheColor(int bx, int by, int lx, int ly) {
    final inSeam = lx % 4 == 0 || ly % 4 == 0;
    if (inSeam) {
      return const Color(0xFF101114);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF191B1F),
        const Color(0xFF272A30),
        const Color(0xFF343941),
      ],
    );
  }

  /// ORAN hsl(23,62%,46%) family — diagonal hazard stripes over dark base.
  static Color _hazardOrangeColor(int bx, int by, int lx, int ly) {
    final stripe = (lx + ly) % 8;
    if (stripe < 3) {
      return const Color(0xFF1D2025);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFFA55727),
        const Color(0xFFBE642D),
        const Color(0xFFD07339),
      ],
    );
  }

  /// RUST hsl(19,58%,38%) family — corroded panel with pitting.
  static Color _rustColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    if (v > 0.92) {
      return const Color(0xFF69341C);
    }
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF814022),
        const Color(0xFF994C29),
        const Color(0xFFB1582F),
      ],
    );
  }

  /// GUN hsl(220,10%,22%) family — smooth technical mechanism plating.
  static Color _gunmetalColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF25272D),
        const Color(0xFF32363E),
        const Color(0xFF40454F),
      ],
    );
  }

  /// BLACKM hsl(220,12%,13%) family — low-contrast matte surface.
  static Color _matteBlackColor(int bx, int by, int lx, int ly) {
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFF101114),
        const Color(0xFF1D2025),
        const Color(0xFF2B2F36),
      ],
    );
  }
}

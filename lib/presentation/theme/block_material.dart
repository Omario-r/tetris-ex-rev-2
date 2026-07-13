import 'dart:ui';

/// Visual block materials for the game's own voxel-space style
/// (presentation only). Palette hues sourced from the "Ronin" ship
/// reference (`ship_ronin_v4.html`) so board blocks, oversleeve materials
/// and (later stories) the ship read as one consistent language.
///
/// Материалы используются в `BlockTheme` и (через `ShipMaterials`) в
/// `ShipPainter` для рисования корабля. Цвет материала — через `color`.
enum BlockMaterial {
  /// Base graphite hull plating (mid-tone cool grey).
  graphite,

  /// Darker graphite plating variant, used for recessed/secondary panels.
  graphiteDark,

  /// Dark recessed niche/inset panel (near-black cool grey).
  darkNiche,

  /// Orange hazard/warning panel plating.
  hazardOrange,

  /// Oxidized rust panel.
  rust,

  /// Gunmetal mechanism plating.
  gunmetal,

  /// Matte black surface.
  matteBlack,
}

/// Цвет материала для рисования (например, в `ShipPainter`).
/// Используется `ProceduralBlockSkin._colorAt` — тот же набор оттенков,
/// что и для текстур полей.
extension BlockMaterialColor on BlockMaterial {
  Color get color {
    switch (this) {
      case BlockMaterial.graphite:
        // GRAF hsl(215,9%,31%) — средний графит
        return const Color(0xFF484E56);
      case BlockMaterial.graphiteDark:
        // GRAF2 hsl(215,9%,26%) — тёмный графит
        return const Color(0xFF3C4148);
      case BlockMaterial.darkNiche:
        // DARK hsl(216,11%,17%) — тёмная ниша
        return const Color(0xFF272A30);
      case BlockMaterial.hazardOrange:
        // ORAN hsl(23,62%,46%) — оранжевая hazard-панель
        return const Color(0xFFBE642D);
      case BlockMaterial.rust:
        // RUST hsl(19,58%,38%) — ржавчина
        return const Color(0xFF994C29);
      case BlockMaterial.gunmetal:
        // GUN hsl(220,10%,22%) — gunmetal
        return const Color(0xFF32363E);
      case BlockMaterial.matteBlack:
        // BLACKM hsl(220,12%,13%) — матовый чёрный
        return const Color(0xFF1D2025);
    }
  }
}

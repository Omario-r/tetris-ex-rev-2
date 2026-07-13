/// Visual block materials for the game's own voxel-space style
/// (presentation only). Palette hues sourced from the "Ronin" ship
/// reference (`ship_ronin_v4.html`) so board blocks, oversleeve materials
/// and (later stories) the ship read as one consistent language.
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

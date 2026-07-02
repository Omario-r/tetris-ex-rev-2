# STYLE — Explosive Template Tetris (visual theme)

> Vision and rules: see [VISION.md](./VISION.md), [DESIGN.md](./DESIGN.md),
> [SPEC.md](./SPEC.md). This document covers only the **visual layer**. It never
> changes game rules; on any conflict with `SPEC.md`, the spec wins.

The game is skinned in a **Minecraft** style: falling tetrominoes are voxel-style
blocks, the explosive piece is TNT, and the Arm button is a creeper face. The
whole theme lives in `presentation/` only — `game_engine/` has no visual logic.

---

## 1. Core principle — atomic, swappable images

Textures are placeholders and will be replaced often. The design guarantees that
**replacing one image never touches any other code**:

- Each material is one isolated **skin** (a `BlockSkin`), unaware of the others.
- There is a **single wiring point** — `BlockTheme` — mapping material → skin.
- Level materials are data, not hardcoded — see `LevelSkin`.

### BlockSkin — the atomic unit

```dart
/// Draws one block into the given rectangle. Atomic visual unit.
abstract class BlockSkin {
  void paint(Canvas canvas, Rect rect, {int? boardX, int? boardY});
}
```

`boardX/boardY` feed deterministic procedural noise so a material looks the same
in the same cell every frame.

Implementations:

- `ProceduralBlockSkin(BlockMaterial)` — the **current placeholder**; draws the
  texture in code (palettes in §4).
- `ImageBlockSkin(ui.Image)` — draws a PNG asset into the cell. Implemented and
  ready, but **not wired in yet**; it is the door to real art.

Special skins/overlays: `TntSkin` (armed piece), `GhostTargetOverlay` (unfilled
S), `HaloHighlightOverlay` (occupied H), `CreeperFacePainter` (Arm button).

### BlockTheme — the single wiring point

```dart
BlockTheme.defaultTheme.of(BlockMaterial.planks); // → the skin to draw
```

`BlockTheme.defaultTheme` maps every `BlockMaterial` to a `ProceduralBlockSkin`.
`copyWithMaterial(material, skin)` returns a copy with one entry replaced (used by
tests and for hot-swapping). Static overlays hang off the class:
`BlockTheme.tnt`, `BlockTheme.ghostTarget`, `BlockTheme.haloHighlight`.

### How to swap one texture

1. Add the PNG under `assets/textures/blocks/` (already registered in
   `pubspec.yaml`).
2. Load it to a `ui.Image` and change **one** entry in the `BlockTheme` map from
   `ProceduralBlockSkin(m)` to `ImageBlockSkin(image)`.

Nothing else changes: `BoardPainter` and every other material are untouched.

---

## 2. Materials and level mapping

`BlockMaterial` (presentation-only enum, **not** an engine concept):
`grass, cobble, planks, bricks, sand, stone, dirt`.

**One level — one block.** `LevelSkin` maps each of the 16 levels to a single
material via `(objectId, fragmentIndex)` from `LevelMap` (SPEC §9). This is a
plain data table, easy to edit:

| Object | Levels | Material | Rationale |
|--------|--------|----------|-----------|
| 0 — House roof (frag 0,1) | 0, 1 | `planks` | wooden roof |
| 0 — House walls (frag 2,3) | 2, 3 | `cobble` | stone walls |
| 1 — placeholder | 4–7 | `sand` | — |
| 2 — placeholder | 8–11 | `stone` | — |
| 3 — placeholder | 12–15 | `bricks` | — |

`LevelSkin.materialForLevel(level)` / `materialForLevelIndex(0..15)` return the
material; `BoardPainter` receives it as `levelMaterial` and draws all occupied
board cells and the (non-armed) falling piece with that one skin.

---

## 3. Rendering rules

- **Block:** 16×16 logical texture scaled into the cell, plus a ~10% light
  top/left + dark bottom/right bevel and a 1px dark outline. The outline is
  required so a piece's shape reads even when all blocks share one material.
- **Ghost (unfilled S):** semi-transparent fill `rgba(120,110,90,0.16)` + dashed
  light outline — the "blueprint".
- **Halo — no grid.** No barriers across the H zone. Only an **occupied** H cell
  (from `GameState.dirtyHalo`) gets a soft warm overlay
  `rgba(255,190,80,~0.12)` + warm stroke `rgba(255,205,95,~0.6)`, with an optional
  `pulse` parameter.
- **TNT:** red body, dark wood caps top/bottom, a white center band with a dark
  `TNT` label, and a yellow-white **fuse spark** above the top edge.
- **Creeper:** green texture + the classic face (two eyes, a T-shaped mouth) on
  the Arm button, shown/enabled only when `state.canArm == true`.

Shared helpers live in `block_paint_utils.dart` (`noise`, `pick`, textured-rect,
bevel, outline). `procedural_block_skin.dart` is the source of truth for exact
hex values.

---

## 4. Placeholder palettes

Logical texture is 16×16; per-pixel color is chosen from thresholds over
deterministic `noise(boardX, boardY, localX, localY)`.

| Material | Base tones | Detail |
|----------|-----------|--------|
| `grass` | top `#6BA832 / #7BBE3A / #8FD14A`, dirt below `#795C3A / #8A6B45 / #9A7A52` | green cap on rows y<3, transition at y=3 |
| `dirt` | `#795C3A / #8A6B45 / #9A7A52` | grass body without the cap |
| `cobble` | `#6B685F / #7D7A72 / #8F8C83 / #A3A097` | dark seams `#3F3C37` on a 4×4 grid |
| `planks` | `#B07F42 / #BD8A4A / #C99A58` | seams `#7C5A2F` every 5 rows, grain `#A9783E` |
| `bricks` | `#8A3C2F / #9E4636 / #B2503C` | mortar `#B7A89A`, rows offset by 4 |
| `sand` | `#D6C184 / #E4D29A / #EFE0AD` | speckle only |
| `stone` | `#7C7972 / #8B8880 / #98958C` | speckle only |
| `tnt` | body `#A83226 / #C0392B / #D1483A` | caps `#7A4A3A`, band `#E9E4DA`, spark `#FFD24A`/`#FFF` |
| creeper | `#438C33 / #4FA03A / #5CB347` | face `#111` |

---

## 5. Constraints (inherited from AGENTS.md / ARCHITECTURE.md)

- Visual logic lives only in `presentation/`; `game_engine/` stays pure.
- Dependencies flow one way; no new `pubspec.yaml` packages (assets only).
- `CustomPainter`, no Flame; `snake_case` files, `PascalCase` classes, `///` docs.
- Do not draw a full Halo grid; do not hardcode level materials in `BoardPainter`.

---

## 6. Tests

- `block_theme_test.dart` — `of()` returns the wired skin; `copyWithMaterial`
  swaps exactly one material (atomicity).
- `level_skin_test.dart` — all 16 levels map to the expected material.
- `board_painter_test.dart` — occupied cells use the level material; armed-piece
  cells use the TNT skin; Arm button contract unchanged.

# ARCHITECTURE — Explosive Template Tetris

## Principles

1. **Pure core** — `game_engine/` contains no `flutter/*` imports. All logic is
   testable without an emulator.
2. **One-way dependencies** — `presentation → application → game_engine`. Reverse
   imports are forbidden.
3. **Determinism** — with a fixed seed or `FixedSequenceGenerator`, results are
   reproducible. This is the basis of testability.
4. **No Flame** — rendering via `CustomPainter`, timing via `Ticker`. Minimal
   external dependencies.

---

## Layers

```text
┌──────────────────────────────────────────────────┐
│  presentation/                                   │  Flutter UI, CustomPainter, gestures
│  board_painter · hud · game_screen               │  imports: flutter/*, application/, game_engine/
├──────────────────────────────────────────────────┤
│  application/                                    │  Ticker → controller.tick(dt)
│  game_loop · progress_service                    │  imports: flutter/scheduler, game_engine/
├──────────────────────────────────────────────────┤
│  game_engine/                                    │  Pure Dart. No flutter/*
│  models/ · rules/ · game/ · data/                │  imports: dart:core, dart:math
└──────────────────────────────────────────────────┘
```

---

## Module structure

```text
lib/
  game_engine/                                    # FORBIDDEN: import 'package:flutter/...'
    models/
      board.dart                                  # Board, Cell — row-major array, 10×20
      piece.dart                                  # PieceType, Piece — 7 tetrominoes, 4×4 matrix
      falling_piece.dart                          # FallingPiece: piece + (x,y) + mode + armedUsed
      level_template.dart                         # LevelTemplate: S, H, moveLimit, objectId, fragmentIndex
      target_mask.dart                            # TargetMask: MSB-first bitmask, up to 8×8 (64 bit)
      object_template.dart                        # ObjectTemplate: id, name, 4 fragments
      fragment_def.dart                           # FragmentDef: anchorX, anchorY, level
    rules/
      collision.dart                              # canMove(), canRotate() — Normal and Explosive
      rotation.dart                               # rotateCW(): transpose + reverse rows
      explosion.dart                              # explodeFootprint(); applyLimitedGravity() is an unused no-op stub (feature dropped — pending removal)
      halo.dart                                   # computeHalo8(), checkWin(): 8-neighborhood
      randomizer.dart                             # SevenBagGenerator, FixedSequenceGenerator
    game/
      game_state.dart                             # GameState (immutable snapshot), GamePhase
      game_controller.dart                        # Public API: all commands + tick(dt)
    data/
      level_map.dart                              # LevelMap: 4 objects × 4 fragments = 16 levels
  application/                                    # FORBIDDEN: import '...presentation/...'
    game_loop.dart                                # Ticker → controller.tick(dt) → notifier
    progress_service.dart                         # shared_preferences: current level index
  presentation/                                   # May import application/ and game_engine/
    theme/                                        # Minecraft skin (see STYLE.md). Swappable per material.
      block_material.dart                         # enum BlockMaterial (presentation-only)
      block_skin.dart                             # abstract BlockSkin — atomic visual unit
      procedural_block_skin.dart                  # placeholder skins (draw texture in code)
      image_block_skin.dart                       # ImageBlockSkin(ui.Image) — ready, not wired yet
      block_paint_utils.dart                      # noise/pick, textured rect, bevel, outline
      tnt_skin.dart                               # TNT block with fuse spark
      overlays.dart                               # ghost target, halo highlight, creeper face
      block_theme.dart                            # BlockTheme: single material→skin wiring point
      level_skin.dart                             # LevelSkin: one level → one material (data table)
    widgets/
      board_painter.dart                          # CustomPainter: Board, Target S, Halo H, falling piece
      hud.dart                                    # Buttons: ←, →, ↻, Arm (creeper), Detonate
      object_full_painter.dart                    # CustomPainter: fully assembled object
      object_fragment_grid_painter.dart           # CustomPainter: object fragment grid
    screens/
      game_screen.dart                            # CustomPaint + HUD + gestures
      level_complete_screen.dart
      object_complete_screen.dart
  main.dart                                       # Entry point: ProgressService → GameScreen(levelIndex)
```

---

## GameController public API

All commands return void. When a command can't be executed, it is a no-op and the
state does not change.

| Command | No-op when |
|---------|-----------|
| moveLeft/Right | at a wall, or no active piece |
| rotateCW | collision after rotation |
| softDrop | no active piece |
| armExplosive | piece is already Explosive, `armedUsed == true`, or no piece |
| detonate | piece is Normal, no piece, or already detonated |
| tick(dt) | phase == won or phase == lost |

---

## Key model invariants

**Board** — `List<Cell>` of length `width × height`, index `i = y * width + x`.

**FallingPiece.mode** — normal | explosive. Transition only normal → explosive,
exactly once per piece (`armedUsed = true`).

**GamePhase** — spawning | falling | won | lost. Transitions are driven only
inside `tick(dt)` and `detonate()`.

**GameState** — an immutable snapshot for the UI. GameController keeps mutable
state internally; it isn't visible from the outside.

**TargetMask** — MSB-first, bit `b = (w*h − 1) − (y * w + x)`. Supports windows up
to 8×8 (Dart `int`, 64 bits).

> Note on Targets: gameplay loads levels from `LevelMap` (16 levels; the House
> uses 5×5 fragment windows). The 6×6 cross mask (`defaultLevel` /
> `defaultTargetMask`, `0x30CFFF30C`) is a reference fixture used by the tests,
> not a level a player sees.

---

## application/ layer

`GameLoop` holds a Flutter `Ticker` and calls `controller.tick(elapsed)` each
frame. It notifies a `ValueNotifier<GameState>` so the `CustomPainter` repaints.
`GameLoop` knows about Flutter but not about `game_engine` internals.

`ProgressService` wraps `shared_preferences` with the key `current_level`
(int, 0..15).

---

## presentation/ layer

**BoardPainter extends CustomPainter** — draws the board, the S zone (Target), the
H zone (Halo, red when it contains clutter), and the falling piece. Repaints via
`repaint: Listenable`, avoiding extra build/layout.

**GameScreen** — CustomPaint + HUD (buttons ←, →, ↻, Arm, Detonate).

**Gestures:** swipe ←/→ → moveLeft/Right(), tap up → rotateCW().

The Arm button is visible and active only when `state.canArm == true`. The
Detonate button is visible and active only when `state.canDetonate == true`.

---

## Import rules (enforced by review / AGENTS.md)

**Forbidden in `game_engine/`:**

```text
import 'package:flutter/...';
import '...application/...';
import '...presentation/...';
```

**Forbidden in `application/`:**

```text
import '...presentation/...';
```

---

## Testability

| Layer | Tool | Environment |
|-------|------|-------------|
| game_engine/ | dart test | No emulator |
| presentation/ | flutter test (WidgetTester) | Flutter test env |
| Integration | flutter test + FixedSequenceGenerator | Flutter test env |

Determinism is guaranteed by `FixedSequenceGenerator(List<PieceType>)` — no RNG,
full control over the sequence.

---

## Meta-progression layer

```text
LevelMap (static)
  └── ObjectTemplate × 4
        └── FragmentDef × 4
              └── LevelTemplate
```

**ProgressService** — `shared_preferences`, key `current_level`: int (0..15).

**Navigation:**
GameScreen → LevelCompleteScreen → (ObjectCompleteScreen?) → GameScreen

**LevelCompleteScreen** — a Canvas with the object's fragment grid; the current
fragment animates into place.
**ObjectCompleteScreen** — a Canvas with the fully assembled object.

> Navigation must capture `NavigatorState` before any `pushReplacement`; see
> `SPEC.md` §6.4 for the exact pattern and rationale.

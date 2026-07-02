# Explosive Tetris

A Tetris variant where the goal is not clearing lines, but assembling a precise
shape. Falling tetrominoes must fill a per-level **Target** while the surrounding
**Halo** is kept clear. Pieces can be armed as **Explosive** to pass through
existing blocks and detonate to surgically remove clutter.

Built with Flutter (pure-Dart game engine, no Flame). Developed with the help of
an LLM coding agent.

## Overview

Each level defines a Target shape (a "fragment"). You stack tetrominoes to fill
the Target exactly, and use the explosive mode to clear anything blocking a clean
finish. A level is won when every Target cell is filled and no clutter touches the
Target's contour (8-neighborhood Halo).

Fragments assemble into objects: four fragments make one object, and the current
prototype ships four objects (the first is a **House**; the rest are placeholder
squares used to exercise navigation) — 16 levels total.

## Key mechanics

- **Target (S):** the set of cells that must be filled to win. Defined per level.
- **Halo (H):** cells adjacent to the Target by 8-neighborhood, but not part of it.
  All in-field Halo cells must be empty to win. Halo cells outside the board are
  ignored, so a Target may touch walls and the floor.
- **Explosive mode:** arm the current piece once per piece to make it pass through
  settled blocks. Detonate manually, or automatically when it reaches the floor.
  A detonation removes only the board cells under the piece's footprint.
- **No post-explosion gravity:** cells emptied by a detonation stay empty; you
  clear the rest with further explosions. Column gravity is out of scope.
- **Rotation:** clockwise only, no wall kicks (SRS is post-MVP).
- **Randomizer:** 7-bag generator, with an optional seed for reproducibility.

## Tech stack

- **Language:** Dart
- **Framework:** Flutter (no Flame)
- **Rendering:** `CustomPainter` / `CustomPaint`
- **Game loop:** `Ticker` / `AnimationController`
- **Persistence:** `shared_preferences` (current level index)
- **Targets:** Android, iOS

## Requirements

- **Flutter SDK** compatible with Dart `^3.10.4` (see `pubspec.yaml`).

## Setup & run

```bash
flutter pub get      # install dependencies
flutter run          # run on a connected device/emulator
```

## Testing

```bash
flutter test                                              # run all tests
flutter test test/game_engine/rules/collision_test.dart   # run one file
flutter analyze                                           # static analysis (zero errors)
```

## Project structure

```text
lib/
├── application/         # Game loop (Ticker → controller.tick(dt))
│   ├── game_loop.dart
│   └── progress_service.dart
├── game_engine/         # Pure Dart game logic (no Flutter imports)
│   ├── data/            # LevelMap: objects, fragments, 16 levels
│   ├── game/            # GameState, GameController
│   ├── models/          # Board, Piece, FallingPiece, LevelTemplate, TargetMask
│   └── rules/           # collision, rotation, explosion, halo, randomizer
├── presentation/        # UI layer
│   ├── screens/         # GameScreen, LevelComplete, ObjectComplete
│   └── widgets/         # CustomPainters, HUD
└── main.dart            # Entry point
```

## Documentation

Russian translations for human reading live in [`docs/ru/`](./docs/ru/) (the
English versions in the root are canonical).

- **`VISION.md`** — why the game exists, audience, core hypothesis.
- **`DESIGN.md`** — game design: core loop, rules, meta-progression, scope.
- **`ARCHITECTURE.md`** — layers, module boundaries, invariants.
- **`SPEC.md`** — technical reference: API, algorithms, edge cases, data structures.
- **`STYLE.md`** — visual theme (Minecraft skin): materials, atomic texture swap, level→material mapping.
- **`ROADMAP.md`** — stages, milestones, and execution tracking (single source of truth for planning).
- **`AGENTS.md`** — instructions for AI agents and contributors.

## Roadmap

Planning and execution tracking live in [`ROADMAP.md`](./ROADMAP.md). The current
stage is polish (UX / visual / sound); the post-MVP backlog (scoring & stars, SRS
rotation and wall kicks, soft/hard drop, per-level move limits, explosion
animations, and the wider meta-progression) is listed there.

## License

TODO: add license information.

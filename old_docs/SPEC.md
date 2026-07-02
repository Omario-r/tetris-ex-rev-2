# SPEC — Explosive Template Tetris (technical reference)

This is the single source of truth for rules, coordinates, data formats, and the
engine API. On any conflict between a prompt and this spec, the spec wins — and
that should be called out explicitly before proceeding.

> **On Targets and the 6×6 cross.** This spec uses a **6×6 cross** as the running
> example and as the reference test fixture (`defaultLevel` / `defaultTargetMask`,
> `0x30CFFF30C`). It is **not** a level a player sees. Actual gameplay loads levels
> from `LevelMap` (§9): 16 levels built from 5×5 fragment windows, starting with
> the House. The cross is kept because the engine tests are written against it.

---

## 1. Terms and conventions

### 1.1 Coordinate system
- `(0, 0)` — top-left corner of the board.
- `x` grows right, `y` grows **down** (like the Flutter Canvas).
- "Floor": `y = height - 1`. Walls: `x = 0` and `x = width - 1`.
- Cell indexing: `i = y * width + x` (row-major).

### 1.2 Terms
- **S** — the set of Target cells that must be filled to win.
- **H (Halo)** — cells adjacent to S by 8-neighborhood but not in S. Computed once
  when a `LevelTemplate` is created and stored on it.
- **Clutter** — any occupied cell not in S.
- **Footprint** — the set of board cells occupied by the falling piece at a given
  moment.
- **Lock** — a falling piece settling into the board's placed blocks.
- **Move (turn)** — the cycle from spawning a piece to its lock or explosion.
- **no-op** — the command is accepted but nothing happens; state doesn't change.
- **Fragment** — a level's Target mask; on a win it settles into place in an object.
- **Object** — a visual figure made of 4 fragments (4 levels).
- **Larger picture** — a meta-layer of multiple objects; out of scope for this
  prototype.

---

## 2. MVP defaults

| Parameter | Value |
|-----------|-------|
| Board size | 10×20 |
| Randomizer | 7-bag, optional seed |
| Halo rule | 8-neighborhood; H cells outside the board are ignored |
| Piece rotation | Simplified CW (no SRS, no wall kicks) |
| Coordinate origin | `y=0` at top, `y` grows down |
| Post-explosion gravity | None — emptied cells stay in place |

### 2.1 Reference fixture — 6×6 thickness-2 cross

Used as the running example in this spec and as the engine test fixture.

Window 6×6. A cell `(x, y)` of the local window is in S if `x ∈ {2,3}` or
`y ∈ {2,3}`.

**ASCII** (`.` = empty, `#` = S):
```
..##..    y=0
..##..    y=1
######    y=2
######    y=3
..##..    y=4
..##..    y=5
```

**MSB-first bitmask (36 bits):**
- Cell `(x, y)` → bit `b = 35 − (y * 6 + x)`.
- `(0,0)` — MSB (bit 35); `(5,5)` — LSB (bit 0).
- Hex: `0x30CFFF30C`
- Bin: `0b001100001100111111111111001100001100`

**Membership test (Dart):**
```dart
bool contains(int localX, int localY) {
  final bitIndex = 35 - (localY * 6 + localX);
  return (mask & (1 << bitIndex)) != 0;
}
```

Fixture placement: `targetX = 2`, `targetY = 14` (= 20 − 6, anchored to the floor),
so S occupies columns 2..7. Field coordinates:
`S_field = { (x + 2, y + 14) | (x, y) ∈ S_local }`.

---

## 3. Game rules

### 3.0 Pieces, spawn, and rotation

**7 tetrominoes — spawn shapes** (4×4 box, `.` = empty, `X` = filled):

```
I:          O:          T:
....        .XX.        XXX.
XXXX        .XX.        .X..
....        ....        ....
....        ....        ....

S:          Z:          J:          L:
.XX.        XX..        X...        ..X.
XX..        .XX.        XXX.        XXX.
....        ....        ....        ....
....        ....        ....        ....
```

**Spawn:** the 4×4 box is placed at the top with
`xStart = (boardWidth − 4) / 2 = 3`, `yStart = 0`.

**CW rotation (simplified, no SRS, no wall kicks):**
- Algorithm: transpose the 4×4 matrix, then reverse each row horizontally.
- If the rotated footprint goes out of bounds or overlaps placed blocks → **no-op**
  (the command is ignored, the rotation isn't applied).
- MVP implements **CW only**. CCW is post-MVP backlog.
- **No wall kicks:** if a rotation is impossible, it's a no-op.

**Edge cases:**
- The O-piece is unchanged by rotation (all 4 states identical).
- The I-piece has 2 unique states (horizontal / vertical).

### 3.1 Spawn and collisions (Normal)

- A new piece spawns in **Normal** mode.
- **Normal collision:** the piece cannot occupy a cell taken by a board border or a
  placed block.
- **Lock:** if the piece can't move to `y+1` due to a collision, it locks; its
  blocks become part of the board; a win check runs.
- `moveLeft()` / `moveRight()` at a wall → **no-op**.
- `softDrop()` speeds up falling (increases the gravity-tick rate); on a bottom
  collision it locks.

**Edge cases:**
- Spawn cells already occupied → **loss** (overflow).

### 3.2 Arming Explosive

- `armExplosive()` switches the current falling piece from `Normal` to `Explosive`.
- Allowed **exactly once** per new piece. Sets `armedUsed = true`.
- **The reverse transition is forbidden.**
- `armExplosive()` is valid only when there is an active falling piece in `Normal`
  mode. In any other state → **no-op**.
- Calling `armExplosive()` again → **no-op**.

### 3.3 Explosive fall and detonation

**Collisions in Explosive:**
- The piece checks collisions **only against the board borders** (walls and floor).
- Placed blocks are ignored: the piece passes through them.
- `softDrop()` works in Explosive the same as in Normal: it speeds up falling and
  doesn't change collision rules.

**Auto-detonation:**
- Happens when **no filled cell** of the piece can move to `y+1` because of the
  bottom border (i.e. at least one piece cell is at `y = boardHeight − 1`).

**Manual detonation:**
- `detonate()` is available at any time while the piece is in `Explosive` mode.
- `detonate()` while in `Normal` mode → **no-op**.

**What an explosion removes:**
- Only the board cells that coincide with the piece's **footprint** at the moment
  of the blast (the intersection of the piece's cells with occupied board cells).
- Empty cells under the piece are untouched.
- Blocks outside the footprint are untouched.
- After the blast the piece disappears; a win check runs.

**Edge cases:**
- An explosion over a fully empty area → no removals.
- Auto-blast and manual blast in the same tick: the `exploded = true` flag prevents
  double handling.
- `detonate()` on an already-detonated piece → **no-op**.

### 3.4 Post-explosion gravity
None, by design. After a blast the empty cells stay in place; the player clears
them with further explosions. Column gravity is **out of scope** — it will not be
added.

### 3.5 Order of steps in tick(dt)

`tick(dt)` is called by the game loop each frame. Manual commands (`moveLeft`,
`rotateCW`, `armExplosive`, `detonate`, etc.) run **outside** tick — immediately on
player action.

```
tick(dt):

  1. if phase == won OR phase == lost
       → return (no-op, game stopped)

  2. if phase == spawning:
       - take the next piece from the generator
       - place it: x=3, y=0
       - if Normal collision at spawn
           → phase = lost; return
       - phase = falling; return
         // gravity applies to the new piece only from the next tick

  3. // phase == falling
     gravityAccum += dt
     if gravityAccum < gravityInterval → return
     gravityAccum -= gravityInterval

  4. if mode == Normal:
       - if canMoveDown() → piece.y += 1
       - else:                          // bottom collision
           → lock the footprint into the Board
           → checkWin:
               if win  → phase = won; return
               if !win → phase = spawning

  5. if mode == Explosive:
       - if canMoveDownExplosive() → piece.y += 1
         // canMoveDownExplosive: checks only the board's bottom border,
         //   i.e. no filled cell of the piece can move to y+1
       - else:                          // hit the floor → auto-detonation
           → explodeFootprint()
           → checkWin:
               if win  → phase = won; return
               if !win → phase = spawning
```

**Manual `detonate()` — a separate command (outside tick):**
```
detonate():
  if mode != Explosive → no-op; return
  → explodeFootprint()
  → checkWin:
      if win  → phase = won
      if !win → phase = spawning
```

**`softDrop()` — a separate command (outside tick):**
```
softDrop():
  → gravityAccum = gravityInterval
  // Forces a gravity step on the next tick.
  // Doesn't call tick() directly — the effect applies through the loop.
```

**Invariants:**
- Auto-detonation happens only inside tick (step 5).
- Manual detonation happens only via the `detonate()` command.
- Double-firing is impossible: after a blast `phase = spawning`, so the next
  frame's tick goes to step 2, not steps 4/5.
- `gravityAccum` is reset when a new piece spawns.

---

## 4. Win and loss checks

### 4.1 Win
Checked **immediately** after every lock or explosion.

**Condition:**
- All S cells are occupied.
- All H cells **inside the board** are empty. (H outside the board is ignored.)

**H is computed once when the level is created:**
```dart
Set<(int, int)> computeHalo(Set<(int, int)> S, int boardW, int boardH) {
  final H = <(int, int)>{};
  for (final (sx, sy) in S) {
    for (final dx in [-1, 0, 1]) {
      for (final dy in [-1, 0, 1]) {
        if (dx == 0 && dy == 0) continue;
        final nx = sx + dx; final ny = sy + dy;
        if (nx < 0 || nx >= boardW || ny < 0 || ny >= boardH) continue;
        if (!S.contains((nx, ny))) H.add((nx, ny));
      }
    }
  }
  return H;
}
```

**Edge cases:**
- S touches a wall/floor → part of H goes out of bounds → ignored (doesn't block a
  win).
- S filled, H has at least 1 clutter block → **not a win**.

### 4.2 Loss
- **Overflow:** spawn cells are occupied when trying to create a new piece.
- (Post-MVP) The move limit is exhausted.

---

## 5. Level data

### 5.1 LevelTemplate
```dart
class LevelTemplate {
  final int boardWidth;       // 10
  final int boardHeight;      // 20
  final TargetMask targetMask;
  final int targetX;          // xStart
  final int targetY;          // yStart
  final int? moveLimit;       // null = no limit
  final int objectId;         // object index (0..3)
  final int fragmentIndex;    // fragment index within the object (0..3)
  late final Set<(int,int)> S;
  late final Set<(int,int)> H;

  LevelTemplate(...) {
    S = _buildS();
    H = computeHalo(S, boardWidth, boardHeight);
  }
}
```

### 5.2 TargetMask (MSB-first)
```dart
class TargetMask {
  final int width;
  final int height;
  final int mask;    // MSB-first, up to 8×8 = 64 bits (Dart int)

  // Note: MVP supports windows up to 8×8 (64 bits).
  // Larger windows require a different storage type.

  bool contains(int localX, int localY) {
    final totalBits = width * height;
    final bitIndex = (totalBits - 1) - (localY * width + localX);
    return (mask & (1 << bitIndex)) != 0;
  }
}
```

**Reference fixture (test-only):**
```dart
final defaultLevel = LevelTemplate(
  boardWidth: 10,
  boardHeight: 20,
  targetMask: TargetMask(width: 6, height: 6, mask: 0x30CFFF30C),
  targetX: 2,
  targetY: 14,
  moveLimit: null,
);
```

### 5.3 Determinism and tests
- `SevenBagGenerator` takes an optional `seed: int?`. With `seed != null`, the run
  is deterministic.
- Integration tests use `FixedSequenceGenerator(List<PieceType>)` — no RNG, full
  control over the sequence.
- Recommended test seed: `seed = 42`.

---

## 6. Engine architecture and API

### 6.1 Module structure
See `ARCHITECTURE.md` for the full tree. Invariants:
- `game_engine/` does not import `flutter/*`.
- Dependencies only downward: `presentation → application → game_engine`.
- All engine operations are deterministic under a fixed seed / `FixedSequenceGenerator`.

### 6.2 GameController public API
```dart
class GameController {
  // All commands: void; when impossible → no-op, state doesn't change.
  void moveLeft();       // shift left; at a wall — no-op
  void moveRight();      // shift right; at a wall — no-op
  void rotateCW();       // CW rotation; on collision — no-op (no wall kicks)
  void softDrop();       // speed up falling; works in Normal and Explosive
  void armExplosive();   // Normal → Explosive, once; otherwise — no-op
  void detonate();       // blast, Explosive only; otherwise — no-op
  void tick(double dt);  // gravity + auto-blast on the floor

  GameState get state;
}
```

### 6.3 GameState (minimum for the UI)
```dart
class GameState {
  final Board board;
  final FallingPiece? fallingPiece;  // null if no active piece
  final GamePhase phase;             // spawning / falling / won / lost
  final LevelTemplate level;
  // UI flags:
  final bool canArm;      // fallingPiece?.mode == Normal && !armedUsed
  final bool canDetonate; // fallingPiece?.mode == Explosive
  final bool isWin;
  final bool isLost;
  // For H highlighting:
  Set<(int,int)> get dirtyHalo =>
    level.H.where((cell) => board.isOccupied(cell)).toSet();
}
```

### 6.4 Navigation-with-callbacks rule
Capture `NavigatorState` via `Navigator.of(context)` once, while the widget is
still mounted, before any `pushReplacement`/`push`. Pass the captured
`NavigatorState` into callbacks as an explicit parameter.

**Forbidden:** using `context` from `State` inside callbacks that run after
`pushReplacement` — by then the `State` is unmounted and its `context` is invalid.

**Correct pattern:**
```dart
final navigator = Navigator.of(context);
navigator.pushReplacement(
  MaterialPageRoute(
    builder: (_) => NextScreen(
      onNext: () => navigator.pushReplacement(...),
    ),
  ),
);
```

**Why:** violating this raises
`"This widget has been unmounted, so the State no longer has a context"`.

---

## 7. Testing

### 7.1 Unit tests (engine, pure Dart)

**Halo (8-neighborhood):**
- All 8 directions are counted (including diagonals).
- H cells outside the board are ignored.
- S at a wall: part of H goes out of bounds → doesn't block a win.

**Win check:**
- S filled, H empty → `isWin = true`.
- S filled, 1 clutter block in H → `isWin = false`.
- S partially filled → `isWin = false`.

**Explosive:**
- The piece passes through placed blocks without locking.
- `armExplosive()` a second time → no-op, mode unchanged.
- Auto-detonation: at least one piece cell at `y = boardHeight − 1`.

**Explosion (footprint):**
- Only cells under filled piece cells are removed.
- Empty cells under the piece are untouched.

**CW rotation:**
- Rotation on collision → no-op, shape unchanged.
- O-piece: 4 CW rotations → same shape.
- I-piece: 2 unique states.

### 7.2 Widget tests (UI)
- S highlighting (Target cells).
- H highlighting: red when H contains clutter.
- Arm button: visible and active only when `canArm == true`.
- Detonate button: visible and active only when `canDetonate == true`.
- Movement gestures/buttons invoke the right commands.

### 7.3 Integration test (1 golden scenario)

**Seed / sequence:** use `FixedSequenceGenerator([I, I, I, I, I, I])` — 6 I-pieces,
enough to fill the 6×2 zones of the cross fixture.

**Scenario:**
1. Start the game with `defaultLevel`.
2. Place pieces filling S (the 6×6 cross at xStart=2, yStart=14).
3. If H contains clutter: arm the current piece (`armExplosive()`), detonate
   (`detonate()`) over the right zone.
4. Assert: `state.isWin == true`.
5. Reproducibility: the same `FixedSequenceGenerator` yields the same result.

**"Done" criteria:**
- All unit/widget tests green.
- `flutter analyze` with no errors.
- The integration test passes reproducibly.
- The manual level scenario is completable on an emulator.

---

## 8. Backlog (post-MVP)

- CCW rotation.
- Wall kicks (SRS or a simplified variant).
- Soft drop vs. hard drop (instant drop).
- Explosion animations (smooth).
- Per-level move limit.
- Sound effects.
- More levels with different Target masks.
- TargetMask for windows > 8×8 (change the storage type).
- Larger picture (a meta-layer above objects, next iteration).
- Multiple fragments on one board at once.
- Free-form fragment docking (anchorX/anchorY instead of a grid).

---

## 9. Meta-progression (extended prototype)

### 9.1 Structure

Object × 4, └── Fragment × 4, └── Level.
Extended prototype: object 0 is complete (House), objects 1–3 are placeholders
(5×5 squares). 16 levels total, linear progression.

### 9.2 New entities (Dart)

```dart
class FragmentDef { final int anchorX; final int anchorY; final LevelTemplate level; }

class ObjectTemplate { final int id; final String name; final List<FragmentDef> fragments; }

class LevelMap {
  static final List<ObjectTemplate> objects = [...];
  static LevelTemplate levelAt(int levelIndex) {
    final obj = objects[levelIndex ~/ 4];
    return obj.fragments[levelIndex % 4].level;
  }
}
```

### 9.3 Object 0 — House (10×10 footprint)

All fragments: Target window 5×5, boardWidth=10, boardHeight=20, yStart=15.

- **Fragment 0 — Left roof:** xStart=0, anchorX=0, anchorY=0. A cell
  `(localX, localY)` is in S if `localX >= (4 - localY)`.
  ASCII: `....X / ...XX / ..XXX / .XXXX / XXXXX`. `TargetMask(width: 5, height: 5, mask: 0x119DFF)`.
- **Fragment 1 — Right roof:** xStart=5, anchorX=5, anchorY=0. A cell is in S if
  `localX <= localY`.
  ASCII: `X.... / XX... / XXX.. / XXXX. / XXXXX`. `TargetMask(width: 5, height: 5, mask: 0x10C73DF)`.
- **Fragment 2 — Left wall:** xStart=0, anchorX=0, anchorY=5. All 25 cells filled.
  `TargetMask(width: 5, height: 5, mask: 0x1FFFFFF)`.
- **Fragment 3 — Right wall:** xStart=5, anchorX=5, anchorY=5. All 25 cells filled.
  `TargetMask(width: 5, height: 5, mask: 0x1FFFFFF)`.

### 9.4 Objects 1–3 (placeholders)

Each: 4 levels, Target window 5×5, mask=0x1FFFFFF, xStart=2, yStart=15,
boardWidth=10, boardHeight=20. objectId=1,2,3 respectively, fragmentIndex=0..3.

### 9.5 Progress persistence

`shared_preferences`, key `current_level`: int (0..15). On failure — repeat. On a
win — value += 1.

### 9.6 Screens

- **LevelCompleteScreen:** Canvas, the object's fragment grid, the current fragment
  animates into place, "Next" button.
- **ObjectCompleteScreen:** Canvas, the whole assembled object, "Next" button.

### 9.7 Tickets

- H1 — ObjectTemplate, FragmentDef, LevelMap, 16 levels — depends on E2
- H2 — ProgressService (shared_preferences) — depends on H1
- H3 — LevelCompleteScreen (Canvas + fragment animation) — depends on H2
- H4 — ObjectCompleteScreen (Canvas, whole object) — depends on H3
- H5 — Navigation: GameScreen → LevelComplete → ObjectComplete → GameScreen — depends on H4

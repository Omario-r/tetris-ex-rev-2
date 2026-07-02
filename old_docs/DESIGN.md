# DESIGN — Explosive Template Tetris

> Vision and core hypothesis: see [VISION.md](./VISION.md).
> Exact rules, coordinates, data formats, and engine API: see [SPEC.md](./SPEC.md).

This document describes the game design. Where a mechanic is not yet in the
prototype, it is marked **(post-MVP)**.

---

## Core loop

Each level defines a Target template. The player moves and rotates falling
tetrominoes to fill the Target shape exactly. If clutter builds up around the
template, the player can use the explosive mode to remove the offending cells
precisely.

You win when the Target is assembled. The focus of the game is not clearing
lines, but neat, precise assembly.

A win is checked immediately after every lock (a piece settling) and every
explosion. On a win, no new piece spawns.

---

## Rules (MVP summary)

Full definitions and edge cases live in [SPEC.md](./SPEC.md). In short:

- **Board:** 10×20. Origin `(0,0)` top-left, `y` grows down.
- **Pieces:** the standard 7 tetrominoes (I, O, T, S, Z, L, J), 7-bag randomizer.
- **Rotation:** clockwise only, no wall kicks (SRS is post-MVP).
- **Target (S):** the cells that must be filled to win. "Holes" inside the shape
  don't matter — only the S cells need to be filled.
- **Halo (H):** all cells adjacent to S by 8-neighborhood that aren't in S. Every
  in-field Halo cell must be empty to win; Halo cells outside the board are
  ignored, so a Target may touch walls and the floor.
- **Clutter:** any occupied cell that isn't part of S. Clutter inside H blocks a win.
- **Explosive mode:** the current piece can be armed exactly once. While armed it
  ignores settled blocks (collides only with the board's borders) and can be
  detonated at any time, or auto-detonates on reaching the floor. A detonation
  removes only the cells under the piece's footprint.
- **No post-explosion gravity:** emptied cells stay empty; the player clears the
  rest with further explosions. Column gravity is out of scope.
- **Win:** all S filled and all in-field H empty.
- **Loss:** a new piece can't spawn (overflow). Move-limit loss is post-MVP.

---

## Session structure

A short level lasts 2–4 minutes. A typical session is 1–2 levels, or one object
made of several fragments.

Object flow:

```text
ObjectPreview → Fragment 1 → pause → Fragment 2 → pause → … → ObjectComplete
```

The session isn't interrupted between fragments of the same object. After each
fragment the player sees a short animation and buttons: **Continue** /
**Save and exit**.

### ObjectPreview

Before an object begins, the player sees the whole object split into fragments.
Already-assembled parts are filled in; the current part is highlighted. The
screen anchors motivation: the player understands where they're heading.

---

## Meta-progression

The player assembles objects fragment by fragment.

| Term | Made of | Levels |
|------|---------|--------|
| Fragment | 1 Target | 1 |
| Object | 4 fragments | 4 |
| Collection | multiple objects | — |

### Prototype content (16 levels)

- **4 objects × 4 fragments = 16 levels**, linear progression. On failure, the
  level repeats.
- **Object 0 — House:** a symmetric house with a stepped roof, split into 4
  fragments that tile without overlap:
  - Fragment 0 — Left roof (stepped triangle)
  - Fragment 1 — Right roof (mirrored triangle)
  - Fragment 2 — Left wall (filled square)
  - Fragment 3 — Right wall (filled square)
- **Objects 1–3 — placeholders:** filled 5×5 squares, used to exercise navigation
  between objects. Exact masks are in [SPEC.md](./SPEC.md) §9.

### Screens between levels

- **After a level:** the object's fragment grid is shown, and the current fragment
  animates into place. Then the next level.
- **After an object:** the fully assembled object is shown. Then the next object.

### Larger picture (post-MVP)

A meta-layer above objects (a collection/gallery). Planned for a later iteration.

---

## Scoring (post-MVP)

Base score:

- +10 for locking a piece into the S zone
- +50 for detonating an explosive piece
- +200 for winning a level

Multipliers:

- ×2 if a piece lands entirely inside S with no stray cells
- +100 for a clean explosion that removes only clutter and doesn't touch S
- Chain of precise locks without an explosion: ×1.5 → ×2 → ×3

Penalties:

- −20 for each dirty Halo cell at the moment of victory
- An explosion over an empty area consumes the tool with no penalty

Level result:

- 1 star — level cleared
- 2 stars — neat assembly
- 3 stars — masterful assembly

### Combo meter (post-MVP)

Grows on precise locks and clean explosions. Cap ×3. Resets to ×1 when leaving a
session.

---

## Explosives economy (post-MVP)

- 5 base explosions per level
- +2 bonus explosions from the daily reward
- Unused base explosions carry over to the next fragment
- Bonus explosions do not carry between fragments
- Leftovers are lost when leaving a session
- `armExplosive()` is a no-op when no explosions remain

> In the current prototype the piece can be armed once per piece with no
> per-level budget; the economy above is a post-MVP design.

---

## Pure Path (post-MVP)

Some templates are designed to be solvable without any explosions.
Condition: the area of S is a multiple of 4 and the shape tiles with standard
tetrominoes.

- Marked with ✦ on the level map, in the Target preview, and via a one-time
  message at the start of the session.
- Bonus +300 in the results for a clean, explosion-free assembly.
- Adds a `hasPurePath: bool` field to `LevelTemplate`.

---

## Retention (post-MVP)

**Daily return:** the first level cleared each day grants +2 bonus explosions. A
"daily object" (2 fragments, continuous session, date-seeded, no replays).

**In-session:** combo meter, carry-over of base explosions between fragments,
progress reset on leaving a session.

**Long-term:** the collection, achievements, weekly events.

---

## Achievements (post-MVP)

Rewards are cosmetic only. Rough plan: many achievements; the exact count is set
after the prototype.

Mastery:

- ✦ Clean assembly — clear a Pure Path level with no explosions
- 💥 Pacifist — clear a level with 0 explosions used

Progress:

- 🔧 First object — assemble the first object
- 🏠 First collection milestone — reach a collection milestone

Architecturally: achievements are a list of `AchievementId` on the player profile;
triggers hang off engine events.

---

## Scope

**In the prototype (MVP):**

- Normal + Explosive modes
- Halo indicator (8-neighborhood)
- Linear meta-progression: 16 levels (House + 3 placeholder objects)
- Progress persistence (`shared_preferences`)

**Beyond MVP:**

- Full scoring and stars
- Pure Path levels
- Daily object and daily reward
- Combo meter and explosion carry-over
- Achievements and the collection gallery
- Monetization

---

## Monetization (post-MVP, preliminary)

- Explosions may be sold as a consumable.
- A subscription is possible.
- Pure Path must always be achievable without purchases.

---

## Open questions

To resolve before going beyond MVP:

- Daily-object reward — mechanic is ready, reward is undefined.
- Streaks — deferred; revisit after the prototype.
- A "Discoveries" achievement category — deferred; revisit after the prototype.
- Weekly challenge — not yet designed.
- Monetization — preliminary: explosions as a consumable + subscription.

---

## UX notes

To describe before going beyond MVP:

- Level HUD (explosion counter, combo meter, current Target)
- Screen flow: Main menu → Level map → ObjectPreview → Game → Results → ObjectComplete

To describe later:

- Onboarding through the first two levels' design (no formal tutorial — see VISION)
- Visual states for Target / Halo / clutter
- Level results screen
- Collection gallery screen

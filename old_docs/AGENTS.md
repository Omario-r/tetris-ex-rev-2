# Agent & Contributor Instructions

Instructions for AI agents and contributors working on **Explosive Template
Tetris**.

## Key documents

Read in this order:

1. **`VISION.md`** — why this game exists, audience, unique mechanic rationale.
2. **`ARCHITECTURE.md`** — layers, module boundaries, invariants, import rules.
3. **`DESIGN.md`** — game design: core loop, rules, meta-progression, scope.
4. **`SPEC.md`** — technical reference: coordinates, data formats, algorithms,
   edge cases, engine API.
5. **`STYLE.md`** — visual theme (Minecraft skin); read when working on visuals.
6. **`ROADMAP.md`** — stages, milestones, and the **Current focus** pointer. Read
   this to see what's active now and where the project stands.

`SPEC.md` is the single source of truth for rules and data. On any conflict
between a prompt and `SPEC.md`, the spec wins — say so explicitly before
proceeding. Always read the relevant `SPEC.md` section before implementing a task.

## Project status & layout

New to the repo? Start at `ROADMAP.md` → **Current focus** to see what's active
and what's already done. In short: the MVP gameplay is complete; the active stage
is polish (UX / visual), with sound as a later stage.

Repo map:

- `lib/game_engine/` — pure-Dart engine: `models/`, `rules/`, `game/`, `data/`.
- `lib/application/` — game loop (`game_loop.dart`) + `progress_service.dart`.
- `lib/presentation/` — Flutter UI: `screens/`, `widgets/`, `theme/`.
- `test/` — mirrors `lib/`; engine unit tests plus widget & integration tests.

Build & run:

```bash
flutter pub get     # install dependencies
flutter run         # run on a connected device/emulator
flutter test        # run all tests
flutter analyze     # static analysis (zero errors/warnings)
```

## Documentation language & translations

The English docs in the repo root are **canonical**. Russian translations for
human reading live in `docs/ru/` and mirror them file-for-file:
`README.ru.md`, `VISION.md`, `DESIGN.md`, `ARCHITECTURE.md`, `SPEC.md`, `STYLE.md`.

**MUST: keep the Russian mirror in sync.** Whenever you change any canonical doc
(`README.md`, `VISION.md`, `DESIGN.md`, `ARCHITECTURE.md`, `SPEC.md`, `STYLE.md`), update the
matching file in `docs/ru/` in the same change, so the two never drift. If you add
a new canonical doc meant for humans, add its Russian translation to `docs/ru/`
and list it in `docs/ru/README.md`.

Not translated (agent/tooling docs, English only): `AGENTS.md`,
`.junie/guidelines.md`.

## Architecture rules

**CRITICAL: `game_engine/` must never import `flutter/*`.**

- `lib/game_engine/` — pure Dart only, zero Flutter dependencies.
- `lib/application/` — game loop (Ticker), depends on `game_engine`.
- `lib/presentation/` — Flutter UI, depends on `application` and `game_engine`.
- Dependencies flow ONE WAY: `presentation → application → game_engine`. Reverse
  imports are forbidden.

## Tech stack

- Flutter (no Flame).
- Rendering: `CustomPainter` / `CustomPaint`.
- Game loop: `Ticker` / `AnimationController`.
- Persistence: `shared_preferences`.
- Tests: Flutter test framework; pure-Dart unit tests for the engine.

## Code conventions

- Engine logic: pure functions where possible, deterministic.
- All public API methods: no-op on invalid input (never throw).
- Coordinate system: `(0,0)` top-left, `y` grows down.
- Piece rotation: CW only (CCW and wall kicks are post-MVP backlog).
- File names: `snake_case`. Classes: `PascalCase`.
- Tests live under `test/` mirroring the `lib/` structure.
- Every public class and method gets a short `///` doc comment.

## What not to do without explicit instruction

- Don't add dependencies to `pubspec.yaml` without agreement.
- Don't touch files outside the task's scope.
- Don't implement backlog items (wall kicks, CCW rotation, scoring, sound, etc.)
  ahead of the roadmap. Note: polish-stage animations such as the explosion effect
  ARE in scope now — check `ROADMAP.md` for what the current stage covers.
- Don't add logic to placeholder/stub files for the current step.

## Quality gates (run before finishing a task)

- `flutter test` — all tests green.
- `flutter analyze` — zero errors and warnings.
- Every engine task includes unit tests; every UI task includes widget tests.

## Non-interactive shell commands

Always use non-interactive flags so commands don't hang on confirmation prompts
(some systems alias `cp`/`mv`/`rm` to interactive mode):

```bash
cp -f source dest       # not: cp source dest
mv -f source dest       # not: mv source dest
rm -rf directory        # not: rm -r directory
apt-get -y ...          # non-interactive apt
```

## Issue tracking — ROADMAP.md (bd retired)

Planning and execution tracking live in **`ROADMAP.md`** (canonical) and its
Russian mirror `docs/ru/ROADMAP.md`. Each stage is a section with checkbox tasks
(`- [ ]` / `- [x]`) and a "done" criterion; the "Current focus" pointer at the
top of `ROADMAP.md` says what's active. Update the checkboxes and the pointer as
work progresses, and leave a short handoff note when ending a session.

The **bd (beads)** tracker that used to live in `.beads/` is **retired**: it held
a single stale skeleton issue and was not used. Don't add new work there. If a
future need for a dependency graph or machine-queryable issues arises, bd can be
revived (`bd bootstrap`), but until then `ROADMAP.md` is the single source of
truth — do not run two competing trackers.

## Ending a work session

- If code changed, run the quality gates above.
- Update `ROADMAP.md` for finished/in-progress work: tick the checkboxes and move
  the **Current focus** pointer.
- Commit; push if the project has a remote and you're expected to.
- Leave a short handoff note for the next session.

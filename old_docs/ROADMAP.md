# ROADMAP — Explosive Template Tetris

> This file is the single source of truth for planning and execution tracking
> (see `AGENTS.md`). Vision, rules and scope live
> in [VISION.md](./VISION.md), [DESIGN.md](./DESIGN.md), [SPEC.md](./SPEC.md);
> this file only sequences the work. The Russian mirror is
> [docs/ru/ROADMAP.md](./docs/ru/ROADMAP.md) — keep the two in sync.

## How this works

- Work is grouped into **stages**; each stage has **milestones** with checkbox
  tasks (`- [ ]` open, `- [x]` done) and a **Done when** criterion.
- The **Current focus** pointer below names the active milestone.
- Update the checkboxes and the pointer as work lands; leave a handoff note at the
  end of a session.

**Current focus:** Stage 2 · Polish — Milestone P0 (visual theme).

---

## Stage 1 — MVP gameplay ✅ (done)

The playable core is complete: pure-Dart engine (Board, pieces, 7-bag, rotation,
collision, explosion, Halo), win/loss checks, 16 levels (House + 3 placeholder
objects), object/fragment flow, progress persistence, and engine + widget tests.

- [x] Game engine and rules (`game_engine/`) with unit tests
- [x] 16-level content and object/fragment progression
- [x] Explosive mode (arm once per piece, footprint detonation, no post-explosion gravity)
- [x] Presentation layer: game screen, HUD, level/object complete screens
- [x] Progress persistence via `shared_preferences`
- [x] Baseline block skin / visual theme (`STYLE.md`) — finishing pass is Stage 2 · P0

---

## Stage 2 — Polish: UX / Visual (next)

Goal: make the existing MVP feel finished — polished skin, readable board,
satisfying feedback — without adding new game rules. Everything stays in
`presentation/`; `game_engine/` is untouched. Sound is a separate stage (Stage 3).

Order: P0 → P1 → P2 → P3.

### P0 — Visual theme finishing
- [ ] Complete the `STYLE.md` block skin: materials, texture polish, level→material mapping
- **Done when:** every block material renders in its intended skin; no placeholder gaps.

### P1 — HUD & cell states
- [ ] Explosion / arm-state indicator in the HUD
- [ ] Current-Target indicator in the HUD
- [ ] Distinct visual states for Target (S) / Halo (H) / clutter cells
- [ ] Build the HUD with headroom for future stars/combo — reserve layout/slots, not wired to logic yet
- **Done when:** a new player can tell S vs H vs clutter at a glance, armed state
  is obvious, and the layout leaves room for stars/combo; widget tests cover the HUD.

### P2 — Animations
- [ ] Explosion / detonation animation
- [ ] fragment → object transition polish
- **Done when:** detonation and fragment-complete read clearly; no jank on device.

### P3 — Level results screen
- [ ] Rework `level_complete` into a proper results screen (scaffold only)
- [ ] Leave placeholders for stars/score (scoring itself stays post-MVP)
- **Done when:** the results screen has room for future scoring without a rewrite;
  widget test in place.

### Stage-2 quality gate
- [ ] `flutter test` green (incl. new HUD/results widget tests)
- [ ] `flutter analyze` — zero errors/warnings

---

## Stage 3 — Sound (separate stage)

Split out from polish (decision O4): sound lands as its own stage after the visual
polish and needs a new dependency, which must be approved before work starts.

- [ ] Add an audio dependency (`audioplayers` or `flame_audio`) — requires sign-off
- [ ] SFX: piece lock, explosion, level win
- [ ] Global mute toggle
- **Done when:** core actions have sound with a global mute; no analyzer warnings.

---

## Decisions (all resolved)

- **O1** — visual theme finishing → Stage 2 · P0.
- **O2** — HUD built with headroom for future stars/combo.
- **O3** — post-explosion / column gravity dropped from scope (removed from DESIGN & SPEC).
- **O4** — sound → separate Stage 3.
- **O5** — no tutorial stage: onboarding happens through level design, per VISION
  (the first two levels teach the mechanic without a formal tutorial).

---

## Backlog — beyond polish (post-MVP)

Tracked here at headline level; details in [DESIGN.md](./DESIGN.md).

- Scoring, stars, combo meter
- Explosives economy (per-level budget, carry-over) and Pure Path levels
- Retention: daily object, daily reward
- CCW rotation and wall kicks (SRS); soft vs. hard drop; per-level move limits
- Achievements and the collection gallery
- Monetization

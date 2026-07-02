# VISION — Explosive Template Tetris

## One line

A mobile puzzle where Tetris mechanics become a tool for precise assembly:
falling pieces are laid into a given template, and an explosive mode lets you
surgically remove everything that doesn't belong.

## Problem

Classic Tetris is a reflex arcade game with no narrative reward. Casual puzzles
(match-3 and the like) lack the physicality of stacking. There's no genre that
delivers the satisfaction of "assembling a part beautifully" while tactically
steering falling blocks.

## Solution

Every level sets a Target template. The player lays tetrominoes to fill the
template exactly, and uses the explosive mode when needed to remove clutter with
precision. Winning isn't "clear a line" — it's "assemble the part perfectly."

## Target audience

Casual players aged 18–35 who value puzzles with a sense of progress. Collecting
objects from fragments creates a satisfying meta-loop.

## Core hypothesis

The explosive mode makes the puzzle controllable and tactical without removing
the tension of stacking pieces.

## Session format

A short level lasts 2–4 minutes with a clear meta-loop. Target pattern: the
player returns 4–6 times a day, clears 1–2 levels per session, and keeps coming
back for the progression: fragment → object → larger picture.

Before a module starts, the player sees the whole object split into fragments.
Already-assembled parts are marked; the current one is highlighted. The player
understands the goal before the first move.

## Narrative layer

The player assembles objects fragment by fragment. Each fragment is a Target; four
fragments complete an object, and objects build up a collection. The first object
is a **House** (a symmetric house with a stepped roof); later objects extend the
collection. Completing every object is the end goal of a run.

> The current prototype ships the House as the first full object; the remaining
> objects are placeholder shapes used to validate navigation. See `DESIGN.md` for
> the meta-progression details and `SPEC.md` for the exact fragment definitions.

## Related documents

- `DESIGN.md` — game rules, progression, retention, MVP scope, and open questions.
- `SPEC.md` — technical reference (coordinates, data formats, engine API).

## Prototype success metrics

- The player understands the mechanic without a tutorial within the first two
  levels.
- The player uses the explosive mode deliberately, rather than spamming it.
- A level is completed in a reasonable number of moves.
- The player reaches the end of the first object without being forced to quit.

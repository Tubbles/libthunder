# WI-0016: map instantiation

Status: backlog

## Goal

Load a map into initial sim state: terrain and pathing from w3e/wpm (WI-0010), placed units/items/doodads/destructables with their per-instance overrides from the doo files (WI-0012), players/forces/start locations from w3i, resolved against the WI-0015 gameplay database.

## Scope notes

- Depends on WI-0014 (the state it instantiates into) and WI-0015 (type definitions the placements reference).
- Placement fields the corpus proved meaningful (WI-0012 log) must be honored: HP/MP overrides, hero levels, owner slots, random-unit modes 0/1/2 (non-payload modes fall back per what oracle observation establishes; until then, documented behavior).
- Neutral players, editor-only entries (special doodads), and map-scope object data all resolve here.
- Instantiation is a command-stream event per decision 0006 (a deterministic "load" command), not out-of-band mutation.

## Acceptance criteria

- Synthetic tests: a hand-built minimal map instantiates to known state; malformed member combinations error cleanly.
- Corpus tests (skipped without data/): a known melee map instantiates with expected unit counts per player, start locations matching w3i, pathing grid dimensions matching wpm; spot values derived independently.
- A gated sweep instantiates all 186 stock maps with zero failures, and the layer-0 harness holds: two instantiations of the same map hash identically.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; sweep counts logged here.

## Log

- 2026-08-10: created from the Phase 2 breakdown (docs/plan-phase-2.md, Track B).

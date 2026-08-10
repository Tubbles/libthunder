# WI-0014: sim scaffolding and layer-0 harness

Status: backlog

## Goal

The deterministic sim skeleton everything in Phase 2 grows inside: tick loop, tick-stamped command stream in/out, per-tick state hashing, snapshot/restore, and the first cut of the headless order/observation API (roadmap Phase 2 deliverable). Ships together with the testing-strategy layer-0 harness.

## Scope notes

- Headless by construction: no rendering, audio, or input dependency anywhere in the package (standing constraint, docs/plan-phase-2.md).
- Lockstep-ready per decision 0006: all state mutation flows through the command stream; reviews reject out-of-band mutation.
- The numeric scalar type lives behind one alias so WI-0013's decision slots in without a refactor; scaffolding work must not accumulate arithmetic that presumes floats or fixed-point.
- No gameplay: the "sim" at this stage advances ticks over a trivial toy state sufficient to prove hashing, snapshotting, and command routing.
- Package layout under src/ decided at implementation (likely src/sim/); gets its own CLAUDE.md if conventions diverge from src/formats/.

## Acceptance criteria

- Layer-0 harness green: two instances fed identical command streams produce identical state hashes every tick; a deliberately diverging instance is detected on the exact tick it diverges.
- Snapshot/restore round-trips: restoring a snapshot and replaying the remaining commands matches the uninterrupted run's hashes.
- Command stream serializes and deserializes byte-identically (the future replay and netcode boundary).
- Headless API can start a session, submit commands, step ticks, and read observations programmatically.
- Passes scripts/check.sh; tests are deterministic (no wall-clock or platform dependence).

## Verification

scripts/check.sh green in CI; layer-0 harness results logged here.

## Log

- 2026-08-10: created from the Phase 2 breakdown (docs/plan-phase-2.md, Track A).

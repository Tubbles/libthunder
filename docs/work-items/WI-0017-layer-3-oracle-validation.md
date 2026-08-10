# WI-0017: layer-3 oracle validation

Status: backlog

## Goal

Stand up the instrumented-map oracle channel against the real 1.29b engine (testing-strategy layer 3): confirm the export mechanism, build the first oracle maps, and establish the pipeline that diffs real-engine measurements against libthunder. Every Track C parity claim and the RNG confirmation (Track A) depend on this instrument.

## Scope notes

- First question, flagged open since the testing strategy was written: does the community Preload file-write technique work on patch 1.29b, and with what path/size/format restrictions? Answer empirically on this machine's real 1.29.2 installation (under Wine), and document the exact mechanics.
- Oracle maps are authored as JASS (war3map.j written by hand or by tooling), packed with our own MPQ knowledge or an external tool; they run in the REAL game only, so no libthunder JASS VM is needed for this work item.
- First measurement targets, chosen for Track C: damage formula samples, a pathing outcome grid, and the RNG experiment WI-0013 specifies.
- The export pipeline (run map, collect Preload output, normalize into committed-format fixtures under data/ or work/) is documented so it is repeatable; measured fixtures derived from the real game are Blizzard-derived data and stay git-ignored, with only our normalized measurement summaries (numbers, not assets) recorded in docs.
- Wine automation depth is discovery, not a commitment: manual runs are acceptable for the first oracle maps.

## Acceptance criteria

- The export channel on 1.29b is confirmed working and documented (mechanics, restrictions), or conclusively ruled out with an alternative channel proposed and validated.
- At least one oracle map runs end to end: authored, executed in the real engine, output collected and parsed by the pipeline.
- The RNG experiment from WI-0013 executes and its measurements are recorded.
- A repeatable runbook exists in docs (how to author, run, and harvest an oracle map).

## Verification

Runbook exercised end to end on this machine; results logged here.

## Log

- 2026-08-10: created from the Phase 2 breakdown (docs/plan-phase-2.md, Track D).

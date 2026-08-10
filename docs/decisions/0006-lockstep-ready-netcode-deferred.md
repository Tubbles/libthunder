# 0006: Sim is built lockstep-ready; netcode is deferred

Date: 2026-08-10. Status: accepted (project owner decision at the Phase 2 breakdown).

## Context

WC3 multiplayer is deterministic lockstep over a per-player command stream, and the roadmap's phases never explicitly placed networking. Building actual netcode inside Phase 2 would front-load transport, session, and sync-recovery work before the sim it synchronizes exists; ignoring networking entirely would risk baking in out-of-band state mutation that lockstep can never tolerate, forcing a costly retrofit.

## Decision

Phase 2 builds the sim lockstep-ready by construction: every state mutation flows through the tick-stamped command stream, the sim is deterministic under layer 0 of the testing strategy, and per-tick state hashes exist for desync detection. Actual networking (transport, sessions, latency hiding) is its own later phase, scheduled when the sim has proven itself against the parity harnesses.

## Consequences

- The command stream is a public architectural boundary from day one; the headless order/observation API and any future netcode are both consumers of it.
- Replay playback (testing-strategy layer 4) and multiplayer share one code path by construction, so layer-4 conformance work directly de-risks the eventual netcode.
- No Phase 2 work item may mutate sim state outside the command stream; reviews enforce this the same way they enforce the robustness rules.
- The deferred phase inherits input-delay mitigation (a Phase 5 grievance), which interacts with lockstep design; the command stream carries explicit tick stamps so delay policy stays a scheduling concern, not a format change.

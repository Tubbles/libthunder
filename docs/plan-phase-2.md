# Phase 2 plan: sim core

Owner-approved breakdown, 2026-08-10. Driving milestone (owner decision): **headless skirmish first** — load a melee map, issue orders through the headless API, units move, fight, and build. JASS and replay conformance follow the milestone rather than gate it. Two stance decisions accompany this plan: numerics are decided by research, not upfront (WI-0013 produces the decision record), and the sim is built lockstep-ready while actual netcode is deferred (decision 0006).

Work proceeds in four tracks. A track's items are sequential; tracks overlap where dependencies allow. Items carry ticket numbers once commissioned; later items are listed here and get tickets when they approach.

## Track A: determinism foundations

- **WI-0013 (ticketed): numerics and RNG research.** How does the real 1.29b engine compute (float semantics, x87 heritage), how far can float-matching go on modern targets including wasm, what does fixed-point cost in layer-4 replay parity, what RNG algorithm does the engine use, and what did open-realm do? Deliverable: a research doc plus the numerics decision record. Everything in Track C consumes the outcome.
- **WI-0014 (ticketed): sim scaffolding and the layer-0 harness.** Tick loop, command stream in/out, per-tick state hashing, snapshotting; headless by construction (the roadmap's headless-mode deliverable starts here as the programmatic order/observation API). Ships with the layer-0 harness: two instances fed identical command streams must produce identical hashes every tick. Largely numerics-agnostic; the numeric scalar type lands behind one alias so WI-0013's outcome slots in.
- **A3 (unticketed): deterministic RNG implementation**, validated against the real engine via oracle maps once WI-0017's channel exists.

## Track B: world state out of Phase 1 formats

- **WI-0015 (ticketed): gameplay data assembly.** Merge the SLK/TXT tables (WI-0007) and object data (WI-0011) into typed unit/item/ability/upgrade/destructable/doodad/buff definitions, driven by the metadata SLKs that map modification ids to fields. Pure data layer, no sim behavior.
- **WI-0016 (ticketed): map instantiation.** w3e/wpm/doo/w3i (WI-0010/0012) into initial sim state: terrain, pathing grid, placed widgets with their overrides, players/forces/start locations.

## Track C: mechanics, dependency ordered (unticketed until commissioned)

- C1: movement and pathing (research-heavy; the real engine's pathing is oracle-map territory).
- C2: orders subsystem (order ids and queue semantics matching the real engine's order strings).
- C3: combat core (attack cycles, damage/armor tables, projectiles, death).
- C4: vision and fog of war.
- C5: economy and production (gold/lumber/food, build/train/research, upgrades).
- C6: abilities and buffs framework, then representative abilities; the long tail of the phase.

The milestone is reached when C5 lands: a melee map loads and two programmatically driven players can fight and build headlessly.

## Track D: parity harness, in parallel

- **WI-0017 (ticketed): layer-3 oracle validation.** Confirm the Preload export channel on real 1.29b, build the first instrumented oracle maps, and establish the diff pipeline. Unblocks A3 and all Track C parity claims.
- D2 (unticketed): .w3g replay format reader and the layer-4 harness skeleton; becomes urgent once Track C nears the milestone. The WI-0013 research already banked replay-format facts for it (community spec: header CRC32, the 128-byte SIGN block, per-turn 0x22 checksum blocks, commands as f32 coordinates); the D2 ticket should start from docs/research/numerics-and-rng.md's sources rather than re-surveying.
- D3 (unticketed): the JASS track — lexer/parser for common.j/Blizzard.j/war3map.j, interpreter, natives on demand, trigger/event glue. Its own mini-phase after the milestone, sized per the process.md subagent policy.

## Standing constraints

- Everything headless: no Track C item may take a rendering or audio dependency (roadmap Phase 2 deliverable).
- Lockstep-ready: all state mutation flows through the tick-stamped command stream; no out-of-band mutation (decision 0006).
- Behavioral claims about the real engine carry sources or oracle measurements, per the project hard rules; where the community documentation is thin, oracle maps (WI-0017) are the instrument.
- Subagent tasks stay small per process.md; each work item above is sized to split into several such tasks.

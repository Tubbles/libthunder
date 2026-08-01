# Testing strategy

Status: draft, written at kickoff. Each layer carries a validation note; nothing here is treated as proven until a work item validates it against the real 1.29b engine.

Parity against the real engine is the core problem: we need data flowing into and out of the original game and World Editor to compare against. The strategy is layered, cheapest first. Real game data always lives in the git-ignored data/ directory; CI-able tests use synthetic fixtures so the repo never depends on Blizzard files.

## Layer 0: our own determinism

Two instances of libthunder fed identical command streams must produce identical state hashes every tick, across platforms and compiler settings. This is a prerequisite for every layer below and for lockstep multiplayer later.

## Layer 1: file format round-trips

Parse, serialize, compare, over a corpus: official files extracted from user-supplied MPQs plus curated community maps. Byte-identical where the format has a canonical encoding; otherwise parse, serialize, reparse, and compare semantically. Third-party parsers with verified licenses (for example StormLib, War3Net) can run beside ours as cross-validation oracles in the pipeline without any code reuse.

## Layer 2: cross-tool round-trips with the real World Editor

Our editor saves a map; the real World Editor (under Wine) must open it and re-save it; we diff the result semantically. And the reverse. Initially manual, later automated if driving the World Editor under Wine/xvfb proves workable. Validation needed: how far the World Editor can be driven headlessly.

## Layer 3: real-engine oracles via instrumented maps

The original game executes JASS in custom maps, so test maps can exercise engine behavior (native functions, damage formulas, pathing outcomes) and export the results from the real game, for example via the community's Preload file-write technique. The same map runs in libthunder and the outputs are diffed. Validation needed: confirm the export channel and its restrictions on patch 1.29b.

## Layer 4: replay conformance

WC3 multiplayer is deterministic lockstep and .w3g replays record the per-player command stream (to be confirmed in the file-format survey). Feeding a replay's commands into libthunder and matching the real outcome is the strongest whole-sim parity check available, and it demands exact RNG, fixed-point, and pathing parity, which is precisely the point. Becomes useful once the sim core exists. Validation needed: exact .w3g structure for 1.29b and what per-tick checkpoints, if any, it contains.

## Layer 5: visual and audio parity

Screenshot comparison (fuzzy) and render golden images once rendering exists. Lowest priority.

Open questions are tracked as work items as they become actionable: World-Editor-under-Wine automation feasibility, Preload export mechanics on 1.29b, .w3g format coverage.

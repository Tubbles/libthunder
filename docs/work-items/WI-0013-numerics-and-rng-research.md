# WI-0013: numerics and RNG research

Status: in progress

## Goal

Settle Phase 2's most consequential open question with data: how the sim represents numbers and randomness. Deliverables: a research document under docs/research/ and a numbered decision record choosing the numeric model, per the owner's research-first stance (docs/plan-phase-2.md).

## Scope notes

- Questions to answer with sources or measurements: how the real 1.29b engine computes (float usage, x87 heritage, any known fixed-point subsystems); how far bit-exact float matching can go across modern x86-64, ARM, and wasm targets in Odin (compiler flags, fused-multiply-add hazards, transcendental functions); what fixed-point costs in layer-4 replay parity terms (event-level vs bit-level conformance); what WC3's RNG algorithm is per community knowledge and how it could be confirmed via oracle maps; what corepunch/open-realm chose and why (MIT, permitted reference).
- The tension being resolved: testing-strategy layer 0 (determinism across our platforms, wasm included) versus layer 4 (bit parity with the real engine's replays). The decision record must state which conformance level layer 4 targets under the chosen model.
- Research only; no sim code. The chosen scalar model lands behind WI-0014's type alias.

## Acceptance criteria

- Research document with a Sources section; every behavioral claim about the real engine cited or marked for oracle confirmation (WI-0017).
- Decision record proposed to the owner with options and a recommendation; accepted before WI-0014 hardens its numeric type.
- The RNG algorithm question either answered with sources or converted into a concrete oracle-map experiment spec for WI-0017.

## Verification

Grounding review per process.md (claims carry sources; license of every consulted codebase verified).

## Log

- 2026-08-10: created from the Phase 2 breakdown (docs/plan-phase-2.md, Track A).
- 2026-08-11: all three research slices returned (engine community research, Odin float-determinism probes, open-realm study; raw findings in work/wi0013-r1/r2/r3-*.md). Owner accepted the f32-plus-discipline recommendation, conditioned on mechanical enforcement; decision 0007 records the policy with the enforcement layers binding. Remaining for closure: the synthesized research doc under docs/research/ and its grounding review.

# 0007: Sim numerics are binary32 floats under an enforced discipline

Date: 2026-08-11. Status: accepted (owner decision from the WI-0013 research; owner conditioned acceptance on the policy being mechanically enforced, which the Enforcement section below binds into the decision).

## Context

Testing-strategy layer 0 demands bit-identical simulation across our platforms including wasm; layer 4 wants conformance with the real 1.29b engine. WI-0013's research (docs/research/numerics-and-rng.md) established: the real sim is binary32 end to end and its lockstep command stream carries raw f32 coordinates, so f32 enters the sim as input no matter what we choose; terrain Z is renderer-derived and outside the authoritative state; Odin's basic f32/f64 arithmetic and sqrt are bit-identical at every optimization level with the pinned toolchain: measured by execution on x86-64 (plus a bit-identical V8 replica), and confirmed at the object-code level for ARM64 and wasm (no FMA contraction, no fast-math flags in the emitted IR; executing on those targets remains open per the research doc), and this is an implementation property, not a language guarantee; libm-routed transcendentals differ by 1 ulp across platforms; float-to-int conversion is hazardous (LLVM poison on out-of-range values, plus an Odin bug truncating i64(f32) through a 32-bit intermediate); math.fmuladd changes results across targets. Fixed-point would be deterministic by construction but guarantees semantic divergence from an engine whose formulas and inputs are float.

## Decision

The sim computes in binary32 under the following policy:

- The sim scalar is `Sim_Real :: distinct f32`. Authoritative state is 2D; Z never enters it, matching the real engine.
- Free-form arithmetic is limited to the measured-stable set: add, subtract, multiply, divide, sqrt.
- Every other math function (sin, cos, atan2, pow, exp, ...) comes from our own simmath package: single-source implementations compiled identically for every target, validated by cross-target bit tests. No libm, no core:math in sim code.
- Float-to-int conversion happens only through simmath's checked helpers (range-checked, defined rounding); raw casts are banned in sim packages.
- math.fmuladd and float transmutes are banned in sim packages.
- Layer 4 (replay conformance) targets event-level conformance first; bit-level parity with the real engine is pursued empirically through oracle formula matching (WI-0017), not assumed.
- The RNG is derived black-box against a real 1.29.2 client (the community's algorithm account is decompiler output and off-limits under clean-room rules); until derived, a deterministic placeholder sits behind the same API shape.

## Enforcement (binding)

Three layers, from accidental to adversarial:

1. Compile-time: `distinct` makes mixing `Sim_Real` with raw f32 a compile error and keeps core:math procedures from accepting it, so the allowed operators work natively and everything else requires simmath or a visible cast.
2. CI-time: scripts/check.sh gains a vet step over sim packages banning `import "core:math"`, `fmuladd`, float `transmute`, and raw float-to-int conversion syntax outside simmath itself.
3. Behavioral: the WI-0013 chain-hash probe becomes a permanent golden-hash test so any toolchain change that alters float codegen fails CI; sim tests compare state hashes across optimization levels; WI-0014's layer-0 harness (two instances, identical streams, identical hashes) backstops everything.

## Consequences

- WI-0014 hardens its numeric alias to `Sim_Real` and ships the vet step and golden-hash test alongside the scaffolding; simmath grows function by function as Track C needs them, each with cross-target bit tests.
- Toolchain upgrades become deliberate events: the golden hash must be re-verified (and re-blessed only with evidence) on every Odin bump.
- The negative-armor pow and any other transcendental in real formulas get simmath implementations whose outputs are compared against oracle measurements before Track C relies on them.
- If oracle work later shows bit-level replay parity is achievable, nothing in this decision blocks it; if it shows our arithmetic cannot track the real engine's, layer 4 remains honest at event-level and this record is superseded knowingly rather than silently.

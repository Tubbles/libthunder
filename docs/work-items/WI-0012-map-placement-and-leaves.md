# WI-0012: map placement and leaf formats (doo, w3c, w3r, w3s, mmp, imp)

Status: backlog

## Goal

Parse the placement files and the remaining small map subformats: `war3mapUnits.doo` (placed units and items), `war3map.doo` (placed doodads and destructables, plus the special cliff-doodad section), `war3map.w3c` (cameras), `war3map.w3r` (regions), `war3map.w3s` (sounds), `war3map.mmp` (minimap icons), and `war3map.imp` (import manifest). Third slice of layer 5 in docs/research/file-formats.md.

## Scope notes

- Corpus versions (WI-0010 survey): both .doo files v7/sub9 (RoC) and v8/sub11 (TFT) with magic `W3do`; w3c v0 (8-float classic shape only); w3r v5; w3s v1; mmp v0; imp v1. Reforged extensions (camera pitch/yaw/roll floats, doo skin IDs) are out of scope; both are unsignaled by version bumps, so the parsers must not silently mis-read them if ever encountered (fail cleanly instead).
- Placement entries reference type IDs defined by the SLK tables and WI-0011 object data; resolution is sim-layer work, not this parser's.
- The imp flags byte semantics are only partially known (research doc); parse it as a raw byte and record observed corpus values rather than inventing an enum.

## Acceptance criteria

- Synthetic-fixture unit tests (CI-runnable): both doo versions including item-drop tables and the special-doodad section, each leaf format, malformed inputs error cleanly without leaks.
- Corpus tests (skipped without data/): spot-check known maps against independently derived values; gated sweep parses all seven formats from every one of the 186 stock maps with zero failures.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus sweep logged here with per-format parse counts.

## Log

- 2026-08-10: created from the WI-0010 map survey; queued behind WI-0011.

# WI-0010: map environment and info formats (w3e, wpm, shd, w3i, wts)

Status: in progress

## Goal

Parse the map subformats a map cannot be loaded without, plus their dimension-coupled companions: `war3map.w3e` (terrain grid), `war3map.wpm` (pathing map), `war3map.shd` (shadow map), `war3map.w3i` (map info), and `war3map.wts` (trigger strings, needed because `w3i` fields reference `TRIGSTR_<n>` keys). First slice of layer 5 in docs/research/file-formats.md; feeds terrain rendering, pathing, and the sim's map-loading path.

## Scope notes

- Versions are corpus-driven (survey below): w3e v11 only, wpm v0 only, w3i v18 (RoC) and v25 (TFT), wts is version-less text, shd is header-less. Later versions (w3e v12, w3i v28+) are out of scope until a corpus needs them.
- The w3i parser must gate fields by version exactly as the format does; War3Net's reader (MIT, verified) is the byte-exact reference for which fields belong to v18 versus v25.
- shd and wpm carry no dimensions of their own (shd) or their own cell grid (wpm); their relationship to w3e's tilepoint grid is off-by-one-prone and undocumented precisely, so it must be pinned empirically against real maps and recorded as a tested invariant.
- wts entries (`STRING <n>`, optional comment, `{ ... }` body) parse into a lookup table; resolving `TRIGSTR_` references is a helper on top, not a rewrite of w3i fields.
- One package per format family under `src/formats/` (naming decided at implementation), read side only.
- References: research doc sections for each format (HiveWE wiki, War3Net source, wc3lib as cross-check; all MIT or reading-permitted, licenses verified there). War3Net pathing-map source copies are in the git-ignored work/map-reference/.

## Acceptance criteria

- Synthetic-fixture unit tests (CI-runnable, zero Blizzard data): hand-built minimal files for each format decode to known values; malformed inputs (truncation, count overruns, bad magic/version) error cleanly without leaks.
- Corpus tests (skipped cleanly when data/ is absent): spot-check known maps with independently derived field values; a gated sweep parses all five formats from every one of the 186 stock maps with zero failures.
- The shd and wpm dimension invariants against w3e are asserted for every corpus map in the sweep.
- w3i TRIGSTR_ references in corpus maps resolve against the same map's wts table.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus sweep run on this machine logged here with per-format parse counts and the pinned dimension invariants.

## Log

- 2026-08-10: created; commissioned by the owner as the map-internals opener after WI-0009 closed.
- 2026-08-10: corpus survey (probe over all 186 stock maps, 45 .w3m + 141 .w3x, all opened by our MPQ reader): w3e present 186/186, all magic `W3E!` v11; wpm 186/186, all magic `MP3W` v0; shd 186/186, every byte length divisible by 256; w3i 186/186, v18 in the 45 RoC maps and v25 in the 141 TFT maps; wts 186/186. Also surveyed for later slices: both .doo files 186/186 (v7/sub9 RoC, v8/sub11 TFT), w3c all v0, w3r all v5, mmp all v0, w3s v1 in 29 maps, imp v1 in 11, object data only in 11 maps (v1/v2), war3map.j always at the archive root (never scripts\), wtg/wct everywhere (out of scope, editor track).

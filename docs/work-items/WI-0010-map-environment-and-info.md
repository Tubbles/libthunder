# WI-0010: map environment and info formats (w3e, wpm, shd, w3i, wts)

Status: done

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
- 2026-08-10: implemented by a subagent in five packages (226b24a, "Add map environment and info readers"): src/formats/w3e, wpm, shd, w3i, wts, one per format. The literature's open questions were pinned empirically over all 186 maps with rival formulas tested to zero matches: wpm width = 4 * (w3e.width - 1) and shd length = 16 * (w3e.width - 1) * (w3e.height - 1), so both sit on the same 4x-per-tile grid keyed to tiles, not tilepoints; wpm bit polarity is set-bit-blocks (no-walk/no-fly/no-build/no-water) with blight (0x20) the one positive bit, matching the w3e blight flag on all 3849 set cells and none of 3.8M clear ones. Both dimension invariants are asserted per map in the gated sweep. Two War3Net w3i reader quirks are mirrored deliberately and unit-tested (a 0xFF byte in place of the upgrade count skips the rest of the file; EOF directly after the upgrade list is valid).
- 2026-08-10: sweep on this machine: 186/186 maps, all five formats, zero failures; 45 v18 + 141 v25; 2150 TRIGSTR_ references in w3i, none unresolved against the same map's wts. Corpus spot-checks (BootyBay v18, EchoIsles v25) assert values derived from independent Python readers.
- 2026-08-10: independent review (second subagent): approved, no HIGH or MEDIUM findings. It re-decoded four maps the committed tests do not use (WarChasers, TranquilPaths, BlizzardTD, Monolith) with its own Python readers and matched every field, reproduced both dimension invariants and the polarity claims independently over all 186 maps (rival formulas 0/186), verified the mirrored quirks against War3Net upstream, and ran ~27k truncation parses under a tracking allocator with zero leaks or bad frees. Four LOW findings; the three actionable ones fixed in ac7d7dc ("Fix map reader review findings"): wpm now rejects zero-dimension files like w3e, two trace-only 32-bit arithmetic corners in w3i and shd are closed, and the named test gaps are filled (w3e wrap fixture, w3i v18 truncation sweep). The fourth is the deliberate 0xFF skip-marker mirror, kept as designed since it is byte-exact to the reference and the corpus maximum upgrade count is 16. Sweep re-run after fixes: unchanged. Status to done.

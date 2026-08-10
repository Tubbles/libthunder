# WI-0012: map placement and leaf formats (doo, w3c, w3r, w3s, mmp, imp)

Status: done

## Goal

Parse the placement files and the remaining small map subformats: `war3mapUnits.doo` (placed units and items), `war3map.doo` (placed doodads and destructables, plus the special cliff-doodad section), `war3map.w3c` (cameras), `war3map.w3r` (regions), `war3map.w3s` (sounds), `war3map.mmp` (minimap icons), and `war3map.imp` (import manifest). Third slice of layer 5 in docs/research/file-formats.md.

## Scope notes

- Corpus versions (WI-0010 survey): both .doo files v7/sub9 (RoC) and v8/sub11 (TFT) with magic `W3do`; w3c v0 (ten-float classic record, corrected from an earlier eight-float note during implementation; see the research doc); w3r v5; w3s v1; mmp v0; imp v1. Reforged extensions (camera pitch/yaw/roll floats, doo skin IDs) are out of scope; both are unsignaled by version bumps, so the parsers must not silently mis-read them if ever encountered (fail cleanly instead).
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
- 2026-08-10: started after WI-0011's implementation landed. Per the updated process.md subagent policy, the implementation is split into three small Opus subagent tasks: (1) the doo placement package (both files, both version pairs), (2) w3c + w3r + mmp, (3) w3s + imp. One full-quality independent review covers the whole work item once all three land.
- 2026-08-10: all three slices landed (16f4722 w3s+imp, 95bc768 w3c+w3r+mmp, 192ef38 doo), each verified on the main line before commit. Corpus-settled highlights, commented at the parse sites: the w3s sound record's int/float field typing is pinned by per-type unset sentinels over all 632 sounds; the imp flags byte resolves against live archive membership (8 = prefixed with war3mapImported, or war3campImported for the campaign, except entries already carrying the prefix; 13 = verbatim; 5 and 10 never occur); the classic camera record is ten floats, correcting the research doc; mmp colours are proven BGRA via the twelve stock player colours; doo random-unit modes outside 0/1/2 occur (mode -1 in 2367 entries, 641 in ten) and carry no payload; wc3lib's larger unit-entry layout tiles no corpus file.
- 2026-08-10: sweeps on this machine: doo 372/372 placement files (90 v7+sub9, 282 v8+sub11), 30323 units, 739932 doodads, 73 special doodads; w3c/w3r/mmp 186/186 maps, 139 cameras, 1668 regions, 4551 preview icons; w3s 32 files (632 sounds), imp 12 files (360 imports, campaign included). All zero failures at exact EOF; spot-checks derive from independent Python readers.
- 2026-08-10: independent full-quality review over all six packages: PASS, no HIGH or MEDIUM findings. It wrote its own decoder from the references and diffed all 974 relevant corpus files field-by-field against the Odin parsers: 974/974 byte-identical, both sides at exact EOF; ~199k truncation-prefix parses per-parser under a tracking allocator with zero accepted prefixes, zero leaks; every corpus-settled claim re-derived exactly. Three LOW findings fixed in 0a2d9fb ("Fix WI-0012 review findings") and this closure: the error-enum naming unified on Trailing_Bytes, a doodad-path wrap-test pin added, and the stale eight-float camera scope note above corrected. Status to done.

# WI-0007: SLK and TXT gameplay data parsers

Status: done

## Goal

Parsers for the SLK (SYLK) gameplay data tables and the INI-style TXT files that live inside the game MPQs. Layer 2 of the implementation order in docs/research/file-formats.md; deliberately scheduled right after the MPQ reader as its first end-to-end validation against real game data.

## Acceptance criteria

- SLK parser handles the ID/B/C record structure per the SYLK reference (sylksum) and WC3's usage patterns; the TXT parser handles [Section] plus key = value INI with quirks recorded as they are discovered.
- Synthetic-fixture tests committed and CI-runnable.
- Corpus tests (skipped cleanly when data/ is absent): parse Units\UnitData.slk, Units\UnitBalance.slk, Units\UnitWeapons.slk and at least one TXT from War3.mpq without error, spot-checking known cell values.
- Strictness policy documented: the real engine is crash-prone on declared-versus-actual column mismatches (file-formats.md); decide and record whether we mirror or diagnose that.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus parse counts logged.

## Log

- 2026-08-01: created from the file-formats survey's implementation order.
- 2026-08-09: implemented as src/formats/slk (sticky-row/column C records, ";;" escape, typed cells) and src/formats/ini (order-preserving sections, // comments, last-wins lookup). Corpus: UnitData/UnitBalance/UnitWeapons/UnitAbilities/UnitUI.slk all parse (837-838 rows each, footman row found in each); UI\MiscData.txt parses with a spot-checked value (Misc/GoldTextColor). Strictness decision recorded in code: out-of-bounds cells are a parse error rather than a crash mirror.
- 2026-08-09: found and fixed an ownership bug the leak tracker caught: Odin defers cannot patch return values after copy-out, so parse now returns an empty table on error instead of a dangling one.
- 2026-08-09: status to in review; independent review pass pending per process.md.
- 2026-08-09: independent review found four probe-confirmed hostile-input defects across this WI and WI-0008: SLK in-cap bounds multiplying to a ~98 GB allocation (and success-with-nil-cells on allocation failure, crashing the first cell access), SLK duplicate B record leaking the prior table, and INI dropping the first section behind a UTF-8 BOM. All fixed with regression tests: total-cell cap, checked allocation, duplicate-B rejection, BOM strip. Done.

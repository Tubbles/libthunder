# WI-0007: SLK and TXT gameplay data parsers

Status: backlog

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

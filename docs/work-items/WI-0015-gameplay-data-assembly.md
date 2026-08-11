# WI-0015: gameplay data assembly

Status: in progress

## Goal

Turn Phase 1's raw tables into the typed gameplay database the sim reads: unit, item, ability, upgrade, destructable, doodad-type, and buff definitions assembled from the SLK/TXT tables (WI-0007) with map object data (WI-0011) applied on top.

## Scope notes

- The metadata SLKs (UnitMetaData.slk and siblings) define the modification-id-to-field mapping; they are the bridge between object-data modification ids and typed fields, and their coverage should be surveyed against the corpus before implementation, Phase 1 style.
- Layering order to confirm against references/oracles: base SLK, TXT overrides, then map object data (original table then custom entries); campaign variants apply per WI-0011's findings.
- Pure data layer: no sim behavior, no derived stats beyond what the tables state. Consumers are WI-0016 and Track C.
- The wrong-shape caveat from WI-0011 applies: shapes come from file extensions, never guessed.

## Acceptance criteria

- Synthetic tests (CI-runnable): layering precedence, leveled modifications applying to the right level, string and numeric field types.
- Corpus tests (skipped without data/): the assembled Footman (and a handful of other well-known entries) carries the expected values from the 1.29.2 tables; a corpus map with object data yields entries reflecting its overrides; spot values derived independently.
- A gated sweep assembles the full database from the base tables plus every corpus map's object data with zero failures.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; sweep counts logged here.

## Log

- 2026-08-10: created from the Phase 2 breakdown (docs/plan-phase-2.md, Track B).

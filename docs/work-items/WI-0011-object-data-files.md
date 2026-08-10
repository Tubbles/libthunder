# WI-0011: object data files (w3u, w3t, w3b, w3d, w3a, w3h, w3q)

Status: backlog

## Goal

Parse the seven object-editor data files: modifications to standard entries and definitions of custom entries for units (`w3u`), items (`w3t`), destructables (`w3b`), doodad types (`w3d`), abilities (`w3a`), buffs/effects (`w3h`), and upgrades (`w3q`). Second slice of layer 5 in docs/research/file-formats.md; these override the SLK gameplay tables (WI-0007) when a map is loaded.

## Scope notes

- One shared container format with two shapes: the simple shape (`w3u`/`w3t`/`w3b`/`w3h`) and the leveled shape adding a level/variation index plus data pointer (`w3a`/`w3q`, with `w3d` carrying a variation index); implement the container once with the shape as a parameter.
- Corpus versions are v1 and v2 only (WI-0010 survey: present in 11 of 186 maps, all scenario/campaign); later versions out of scope until needed.
- The modification values are typed (int/real/unreal/string) by a type tag in the file; the mapping is documented in the research doc's sources (War3Net Object directory, HiveWE wiki).
- Read side only; merging modifications onto SLK data is sim-layer work, not this parser's.

## Acceptance criteria

- Synthetic-fixture unit tests (CI-runnable): both shapes, both versions, all four value types, malformed inputs error cleanly without leaks.
- Corpus tests (skipped without data/): spot-check a map's object data against independently derived values; gated sweep parses every object-data file in all 186 stock maps with zero failures.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus sweep logged here with per-extension parse counts.

## Log

- 2026-08-10: created from the WI-0010 map survey; queued behind WI-0010.

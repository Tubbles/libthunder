# WI-0011: object data files (w3u, w3t, w3b, w3d, w3a, w3h, w3q)

Status: done

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
- 2026-08-10: started after WI-0010 closed. Corpus widened: data/Warcraft III/Campaigns/DemoCampaign.w3n opens directly with our MPQ reader and carries war3campaign.w3u and war3campaign.w3t (same format, campaign-scoped) plus three embedded maps; the campaign files and, if practical, the embedded maps' object data join the sweep alongside the 11 stock maps.
- 2026-08-10: implemented by a subagent as src/formats/object_data (15e37cc, "Add object data reader"): one container parser with a Simple/Leveled shape parameter. The implementation agent was cut off mid-task by a session usage limit and revived from its transcript per the updated process.md; it resumed cleanly. Corpus-settled facts, each commented at the parse site: v1 and v2 share one identical layout (references branch only at v3, patch 1.33), contradicting wc3lib's level-data-is-v2 claim, proven by Monolith's leveled v1 w3a; both tables' entries carry old and new ids; the per-modification trailing int32 is semantically dead and stored verbatim (35628 zero, 7734 old-id echo, 405 unrelated rawcodes next to uico/umdl/usnd string modifications).
- 2026-08-10: sweep on this machine: 186 maps opened, 61 object files, 0 failures at exact EOF; per extension w3u 15, w3t 13, w3b 7, w3d 7, w3a 9, w3h 7, w3q 3; versions 13 v1 / 48 v2; includes the campaign's war3campaign.w3u/.w3t and its three embedded maps (Demo03/04/05.w3m) staged out of the campaign archive. Spot-check values derive from an independent Python reader.
- 2026-08-10: independent review: approved, no HIGH or MEDIUM findings. It re-decoded four files the committed tests do not use (WarChasers w3u, AzerothGrandPrix w3d, BomberCommand w3q, an embedded campaign map's w3u) byte-identically against its own Python reader, reproduced every corpus-settled number exactly, and ran 20864 truncation parses under a tracking allocator with zero leaks. Five LOW findings, four fixed in cee4042 ("Fix object data review findings"): the wrong-shape limitation (3 corpus files parse under the opposite shape via string realignment, inherent to the marker-less format) is documented on parse and pinned by two tests, the sweep asserts the exact known corpus counts so coverage cannot silently shrink, and the end-token comment carries the full uico/umdl/usnd tally. The fifth finding was this missing log entry. Status to done.

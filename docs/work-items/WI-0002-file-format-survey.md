# WI-0002: File format survey

Status: done

## Goal

Map the WC3 data format landscape for the 1.29b target: containers (MPQ), assets (BLP, MDX/MDL, SLK/TXT, FDF), map internals (war3map.*), JASS, replays (.w3g), campaigns. Identify where authoritative documentation lives and where reverse engineering will be needed.

## Acceptance criteria

- docs/research/file-formats.md exists, covering containers, asset formats, map internals, JASS, replays, and campaigns.
- Each format records purpose, documentation location and quality, existing parsers with verified licenses, and per-patch variation risk.
- Confirms the MPQ-to-CASC cutover patch with sources.
- Ends with a dependency-ordered implementation order recommendation.

## Verification

Grounding review pass per process.md.

## Log

- 2026-08-01: created; research agent dispatched.
- 2026-08-01: report landed in docs/research/file-formats.md (434 lines). MPQ-to-CASC cutover pinned to 1.30.0 by three converging sources; 1.29.2 is the last MPQ patch, matching decision 0003. WC3 uses MPQ v1 only. Scary gaps flagged for black-box work: FDF/TOC (no spec, no parser anywhere), .w3z saved games (undocumented), Reforged .w3g (out of scope). Ends with a 9-layer dependency-ordered implementation plan.
- 2026-08-01: grounding review passed. Independently re-verified: jassdoc carries common.j/Blizzard.j at repo root; w3g_format.txt v1.18 (2007, blue/nagger) matches the cited header; wc3lib customunits.cpp implements the per-set v3 object-data loop (the parser trap the doc warns War3Net gets wrong); WarRaft/mpq-rs is MIT.

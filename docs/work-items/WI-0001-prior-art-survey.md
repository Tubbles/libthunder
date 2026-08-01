# WI-0001: Prior art survey

Status: done

## Goal

Survey open source WC3 engine reimplementations, format tooling, and adjacent RTS/engine reimplementation projects; identify what can be leveraged and how.

## Acceptance criteria

- docs/research/prior-art.md exists, covering at least open-realm, WarSmash, War3Net, StormLib/CascLib, wc3lib, HiveWE, w3x2lni, mdx-m3-viewer, JASS tooling, replay parsers, and adjacent projects (OpenRA, openage, OpenSAGE, OpenMW, devilutionX, Spring/Recoil).
- Every project has a verified license and a "usable how" verdict (reference-only, license-compatible-for-study, or test-pipeline tool).
- Every claim carries a source URL or an explicit unverified marker.

## Verification

Grounding review pass per process.md: license claims spot-checked against upstream repos, sources spot-checked.

## Log

- 2026-08-01: created; research agent dispatched.
- 2026-08-01: report landed in docs/research/prior-art.md (21+ projects, all licenses verified by the agent against LICENSE files).
- 2026-08-01: grounding review passed. Independently re-verified via `gh api`: WarsmashModEngine AGPL-3.0, War3Net MIT, HiveWE AGPL-3.0, pjass BSD-2-Clause. Key findings: the WC3 full-engine field is nearly empty (open-realm, WarSmash, War3Net only); open-realm is MIT with a full JASS VM and in-tree MPQ reader; OpenMW/OpenSAGE are the clean-room methodology precedents to cite, devilutionX (IDA-derived lineage) the pattern to avoid.

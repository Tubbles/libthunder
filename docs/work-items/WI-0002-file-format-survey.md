# WI-0002: File format survey

Status: in progress (research agent running since 2026-08-01)

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

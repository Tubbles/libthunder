# WI-0009: MDX model reader

Status: in progress

## Goal

Parse WC3's binary model format (MDX) into typed Odin structures: geometry, materials/textures, bones and node hierarchy, animation sequences and keyframe tracks, particle emitters, and the remaining classic chunks. Layer 4 of the implementation order in docs/research/file-formats.md; the first format that feeds the renderer's model pipeline and the sim's collision/attachment data.

## Scope notes

- Classic MDX only (the 1.29.2 corpus; VERS 800 era). Reforged chunks (CORN, FAFX, BPOS, TANG/SKIN sub-chunks) are out of scope until a corpus needs them.
- Read side only; the MDL text format and any writer come later with the editor track.
- Chunk coverage is corpus-driven: the survey below establishes which chunk tags actually occur in the 1.29.2 archives, and every occurring tag must parse. Unknown tags are skipped by their size field, matching the chunked container design.
- Keyframe tracks (the K*** sub-chunks) share one generic layout (count, interpolation type, global sequence id, then per-key time + value, plus in/out tangents for Hermite/Bezier); the parser should implement that once, generically.
- Primary spec: Magos's "The MDX file format!" (docs/research/file-formats.md carries the URL and provenance). Cross-checks against the MIT-licensed parsers listed there (ReterasModelStudio, mdx-m3-viewer, war3-model) are permitted reading; barncastle/MDXReForged has no license and must not be studied.

## Acceptance criteria

- Synthetic-fixture unit tests (CI-runnable, zero Blizzard data): hand-built minimal MDX files decode to known structures, malformed headers/chunks error cleanly without leaks.
- Corpus tests (skipped cleanly when data/ is absent): parse known models from War3.mpq with spot-checked field values derived independently (external parser or hand-read hex), and a gated sweep that parses every .mdx in the manifest archives with zero failures.
- Every chunk tag occurring in the corpus parses into typed data (no opaque byte-blob passthroughs for occurring chunks).
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus sweep run on this machine logged here with per-archive parse counts and the chunk tag histogram.

## Log

- 2026-08-09: created; commissioned by the owner after WI-0006/0008 closed. Starting with a corpus survey of chunk tags and versions.
- 2026-08-09: corpus survey (probe over every listfile .mdx in the five manifest archives): 3362 files (War3.mpq 2049, War3x.mpq 1313, none elsewhere), every one VERS 800 with valid MDLX magic, and the top-level chunk walk tiles every file exactly (0 anomalies). Occurring tags with file counts: MODL/VERS 3362, SEQS 3360, PIVT 3346, TEXS 3330, MTLS 3171, BONE/GEOS 3149, GEOA 1469, HELP 1371, PRE2 1166, EVTS 999, GLBS 947, ATCH 685, CAMS 668, CLID 542, LITE 203, RIBB 155, TXAN 77, PREM 31. No SNDS and nothing Reforged-era, so the parser targets exactly these 20 chunks.

# WI-0008: BLP and TGA texture decoding

Status: in progress

## Goal

Decode WC3's texture formats to RGBA8 pixel buffers: BLP1 (both palettized and JPEG-content flavors, with mipmaps) and TGA. Layer 3 of the implementation order in docs/research/file-formats.md; first render-relevant assets.

## Scope notes

- BLP1 only; BLP0 (beta-era external mipmaps) deferred until a real corpus file needs it, BLP2 is WoW-only (out of scope).
- Documentation here is reverse-engineering-grade (research doc flags it); the corpus itself is the authority. Header-field distributions are surveyed from the real archives before implementation.
- JPEG-content BLPs embed a shared header plus per-mipmap JPEG streams with 4-component pixel data; decoder choice (core:image/jpeg vs vendor:stb) validated against real files.
- TGA via core:image/tga if it covers the corpus files, else a minimal loader for the uncompressed 32-bit subset WC3 uses.

## Acceptance criteria

- Synthetic-fixture tests (CI-runnable): hand-built palettized BLP1 decodes to known pixels, malformed headers error cleanly.
- Corpus tests (skipped without data/): decode known BLPs of each flavor from War3.mpq, verify dimensions and stable content hashes; decode at least one real TGA.
- Mipmap access: decode any mip level, count exposed.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus decode counts and flavor histogram logged here.

## Log

- 2026-08-09: created; started with a corpus survey of BLP header fields.
- 2026-08-09: survey results (War3.mpq + War3x.mpq): all files are BLP1, none BLP0. JPEG-content ~5067 files, palettized ~1591. alpha_bits only ever 0 or 8. Alpha-plane rule established empirically: present iff alpha_bits is 8; the picture_type field (2/3/4/5 observed) does not affect layout, and every file's size reconciles exactly under this rule.
- 2026-08-09: embedded JPEG structure verified from real files: baseline SOF0, 8-bit, exactly 4 components, all 1x1 sampling, shared SOI+DQT+DHT header (572 bytes) with per-mip SOF0+SOS streams carrying per-mip dimensions. core:image/jpeg is 3-component YCbCr-only, so a specialized raw-plane baseline decoder is being built by a subagent (synthetic PIL-generated fixtures, no Blizzard data committed).
- 2026-08-09: palettized decode implemented and verified against Python-derived reference pixels from the corpus (SelectionCircleLarge alpha ring values). TGA wrapper over core:image/tga landed after discovering the loader's alpha_add option writes no alpha for TGA (channel expansion done in the wrapper); orientation normalization confirmed against a Pillow reference decode of a bottom-left-origin 24-bit pathing texture.

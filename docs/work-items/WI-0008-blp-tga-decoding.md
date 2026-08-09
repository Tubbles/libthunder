# WI-0008: BLP and TGA texture decoding

Status: done

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
- 2026-08-09: independent review: palettized BLP path clean (no findings). TGA finding fixed with a regression test: zero-dimension headers are now pre-rejected, since the core loader accepts them and then leaks its Image struct in destroy (upstream Odin bug, noted in SUGGESTIONS.md).
- 2026-08-09: JPEG-content decode landed in 6c560b7 ("Decode JPEG-content BLP1 textures"): a from-scratch baseline decoder (thunder:formats/jpeg) returning raw component planes, since core:image/jpeg is 3-component YCbCr-only. Output cross-validated against an independent Pillow decode: at most a difference of 1 per channel, from IDCT rounding.
- 2026-08-09: the first full sweep failed on exactly one of 6658 BLPs: Editor-Toolbar-MapValidation.blp stores a truncated 10-entry palette with mip 0 starting 40 bytes after the header. Fixed in 32da51d ("Accept truncated palettes in palettized BLP1 files"): the palette ends wherever the first mip begins, and every index is validated against the entries actually stored. Pixels cross-checked against an independent Python decode.
- 2026-08-09: independent review of the JPEG work returned two MEDIUM findings (SOF dimensions drove plane allocations unchecked, so a malformed stream claiming 8192x8192 allocated ~256 MiB before failing; a scan referencing never-defined Huffman/quantization tables decoded silently into garbage because a zero-valued table reads as a 1-bit code) and two LOW (no synthetic JPEG-flavor BLP fixture in CI; a dead negativity check). All four fixed in 809e359 ("Fix JPEG review findings"): the decoder now takes caller-expected dimensions and rejects a disagreeing SOF before allocating, tables carry a defined flag, and a hermetic JPEG-flavor BLP fixture covers decode_jpeg_mip without game data. Reviewer also spot-checked TjShockwave2.blp against Pillow (max diff 1 per channel) and confirmed clean-room provenance.
- 2026-08-09: final sweep after all fixes: War3.mpq 3677 + War3x.mpq 2981 = 6658 BLPs decode mip 0, 0 failures (flavor histogram from the survey: ~5067 JPEG-content, ~1591 palettized). scripts/check.sh green. Status to done.

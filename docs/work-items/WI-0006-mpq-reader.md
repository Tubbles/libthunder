# WI-0006: MPQ v1 reader

Status: in review

## Goal

A from-scratch MPQ v1 reader in Odin, sufficient to open the base game archives (War3.mpq era) and .w3x/.w3m map archives and extract files. Layer 1 of the implementation order in docs/research/file-formats.md; everything except replays depends on it.

## Scope notes

- v1 only: WC3's Storm.dll effectively always parses archives as v1 (file-formats.md, citing StormLib source comments). No HET/BET tables, no 64-bit offsets.
- Read side first; the writer comes later with the editor track and round-trip tests.
- Decompression: zlib/deflate, PKWARE DCL implode, bzip2, sparse/RLE, IMA ADPCM mono and stereo; combined-method sectors decompress in the fixed documented order.
- Decryption: hash and block tables plus optional file sectors, using the 1280-entry table cipher for which wowdev.wiki carries worked test vectors.
- Map archives: the 512-byte HM3W wrapper, and the 512-byte-aligned scan for the MPQ magic that the real engine performs (protected maps abuse this; match engine behavior, per file-formats.md).

## Acceptance criteria

- Synthetic-fixture unit tests (committed, CI-runnable, zero Blizzard data): cipher test vectors, hash function, and a tiny hand-built archive round-tripped through the reader.
- Corpus tests (skipped cleanly when data/ is absent): enumerate and extract known files from War3.mpq and the stock .w3m maps pinned in docs/asset-manifest.md; spot-verify extracted content against independently obtained reference hashes (for example via StormLib as an external oracle).
- Opens archives by known internal path even when no listfile is present.
- Passes scripts/check.sh.

## Verification

scripts/check.sh green in CI; corpus test run on this machine logged with per-archive extraction counts.

## Log

- 2026-08-01: created from the file-formats survey's implementation order.
- 2026-08-09: implemented in src/formats/mpq. Cipher and hash verified against the format's published reference constants; synthetic archives cover raw, encrypted, zlib single-unit, HM3W-prefixed, and header-scan paths. PKWARE explode, Huffman, and ADPCM codecs were built by subagents in isolated scratch packages against StormLib/blast references (read, not copied) and integrated after their own test suites passed (10 + 14 tests).
- 2026-08-09: full corpus sweep (THUNDER_CORPUS_SWEEP=1): every listfile entry of every manifest archive extracts. War3.mpq 9168, War3x.mpq 7671, War3xLocal.mpq 2555, War3Local.mpq 1315, Deprecated.mpq 669; 21378 total, 0 missing, 0 unsupported, 0 failed. bzip2/sparse never occur in the 1.29.2 corpus and remain intentionally unimplemented (error cleanly).
- 2026-08-09: status to in review; independent review pass pending per process.md.

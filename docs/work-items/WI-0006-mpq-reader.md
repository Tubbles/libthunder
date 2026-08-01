# WI-0006: MPQ v1 reader

Status: backlog

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

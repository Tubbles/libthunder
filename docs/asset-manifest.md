# Asset manifest

The reference game data used for parity testing on dev machines. The files themselves are Blizzard's, live only in the git-ignored data/ directory, and are never committed; this manifest records their identity (sha256) so every machine and test run works against the exact same corpus.

Provenance: `scripts/download-game-data.sh`, which mirrors corepunch/open-realm's `make download` (archive.org item `warcraft-iii-installer-enus`, file `Warcraft-III-1.29.2-enUS.zip`, patch 1.29.2, the last MPQ-based release line). Downloaded and hashed 2026-08-01. An existing legal installation can be used instead via the script's path argument, but then these hashes must be re-checked before trusting corpus-based golden tests.

## data/Warcraft III/

| File | sha256 |
|---|---|
| War3.mpq | 60a4e380b3ae753b304be837edac53bebed0ae69b611e7f2ebfc2b036bf00d47 |
| War3x.mpq | 69fb8fd8aefe1657d75d53f970e20dbd9d9c23d42a3c2582cca4a97a16becfc7 |
| War3Local.mpq | f986d2767f341e9a665ece3807e9242b254ba1efad6d2858304eb11166aef8fd |
| War3xLocal.mpq | ba7b928c7bf34fb2a1675aeddfdadcfdc7146966ae7ebf36b0980486b7dd9c57 |
| Deprecated.mpq | 949304288eb3acf7b7214a1c1ef834772effa2d89dcebd9c995c321be017ccf7 |
| Warcraft III.exe | a1950f17905b9cd7d5461d45e6723af36dda5304e12dba27a1fea85593b15f3f |
| World Editor.exe | e4547515dfa570f2f3450fd83249db59896b0a7896110f2c8897fb3fc9eb9e6e |

Also present: `Maps/` with the stock melee maps (.w3m) and `Campaigns/DemoCampaign.w3n`, both useful as round-trip corpus inputs; `World Editor.exe` gives us the real World Editor binary for the Wine-based cross-tool round-trip layer of docs/testing-strategy.md.

Note: the patch level rests on the archive's own naming (1.29.2) and file dates (2018-05); verify the version string in-engine before citing exact-patch behavior in tests.

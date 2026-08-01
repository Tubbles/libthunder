# Prior art survey for libthunder

Research date: 2026-08-01.
This survey covers existing open-source projects relevant to libthunder, a clean-room reimplementation of the Warcraft III engine and world editor written in Odin.
Every factual claim below was verified against a live source (a fetched LICENSE file, a `gh api` call, a README fetched directly) during this research session, not inferred from memory or a badge.
Claims that could not be independently verified are marked "unverified" inline.
See the Sources section at the end for the full citation list.

## Summary table

| Project | Language | License (verified) | Status as of 2026-08-01 | Usable how |
|---|---|---|---|---|
| [corepunch/open-realm](https://github.com/corepunch/open-realm) | C | MIT | Very active, commit today | Reading reference (author-authorized); MIT also permits code study/adaptation |
| [WarsmashModEngine (Retera)](https://github.com/Retera/WarsmashModEngine) | Java | AGPL-3.0 | Active but fragmented across branches; `main` last merged 2025-12-09 | Reference-only (AGPL) |
| [War3Net (Drake53)](https://github.com/Drake53/War3Net) | C# | MIT | Very active, commit today | License-compatible-for-study; tool-we-can-run-in-our-test-pipeline |
| [StormLib (ladislav-zezula)](https://github.com/ladislav-zezula/StormLib) | C | MIT | Active, last commit 2026-07-13 | License-compatible-for-study; tool-we-can-run-in-our-test-pipeline |
| [CascLib (ladislav-zezula)](https://github.com/ladislav-zezula/CascLib) | C/C++ | MIT | Active, last commit 2026-07-21 | License-compatible-for-study; tool-we-can-run-in-our-test-pipeline |
| [wc3lib (tdauth)](https://github.com/tdauth/wc3lib) | C++ | GPL-2.0 | Low activity, single maintainer, last push 2026-03-13, JASS/MDLX modules self-described unfinished | Reference-only |
| [HiveWE (stijnherfst)](https://github.com/stijnherfst/HiveWE) | C++ | AGPL-3.0 | Very active, last commit 2026-07-28 | Reference-only for code; tool-we-can-run-in-our-test-pipeline as a black box |
| [w3x2lni (sumneko)](https://github.com/sumneko/w3x2lni) | Lua + C++ | GPL-3.0 | Moderately active, latest release 2.7.3 (2025-12-18) | Reference-only for code; possible tool-we-can-run-in-our-test-pipeline pending Linux build |
| [mdx-m3-viewer (flowtsohg)](https://github.com/flowtsohg/mdx-m3-viewer) | TypeScript | MIT | Self-declared "NO LONGER ACTIVELY MAINTAINED"; last commit 2025-08-27 | License-compatible-for-study; tool-we-can-run-in-our-test-pipeline (pin a commit, not npm) |
| [pjass (lep fork)](https://github.com/lep/pjass) | C | BSD-2-Clause | Active, last commit 2026-06-15 | Tool-we-can-run-in-our-test-pipeline (syntax oracle) |
| [WurstScript](https://github.com/wurstscript/WurstScript) | Java | Apache-2.0 | Very active, commit today | License-compatible-for-study; tool-we-can-run-in-our-test-pipeline (JASS corpus generator) |
| [jasshelper / vJass (shuen4)](https://github.com/shuen4/jasshelper) | Pascal | zlib | Active, single maintainer, last commit 2026-06-07 | License-compatible-for-study; possible pipeline tool via Wine/FPC |
| [jass2 (hackwaly)](https://github.com/hackwaly/jass2) | OCaml | MIT | Dead, last commit 2020-04-02 | Reference-only |
| [jass2_interpreter (Waffle_est)](https://bitbucket.org/Waffle_est/jass2_interpreter) | Python | Unknown/no license found | Dead, last update 2015-06-20 | Reference-only |
| [JiffyJass](https://www.hiveworkshop.com/threads/jiffyjass-standalone-jass-interpreter.326548/) | Unknown (Windows binary only) | No license found, closed source | Dormant, last binary 2020-12-15 | Reference-only |
| [w3gjs (PBug90)](https://github.com/PBug90/w3gjs) | TypeScript | MIT | Active, last commit 2026-04-29 | Tool-we-can-run-in-our-test-pipeline |
| [wc3v (jblanchette)](https://github.com/jblanchette/wc3v) | JavaScript | GPL-3.0 | Very active, last commit 2026-07-31 | Tool-we-can-run-in-our-test-pipeline |
| [w3g (scopatz)](https://github.com/scopatz/w3g) | Python | CC0-1.0 | Unmaintained, last commit 2020-10-23 | Tool-we-can-run-in-our-test-pipeline |
| Other WC3 engine reimplementations | — | — | None found beyond open-realm, WarSmash, War3Net | N/A |
| [OpenRA](https://github.com/OpenRA/OpenRA) | C# | GPL-3.0 | Very active, last commit 2026-07-23 | License-compatible-for-study |
| [openage (SFTtech)](https://github.com/SFTtech/openage) | C++ / Python | GPL-3.0+ (narrow LGPL-2.0/BSD exceptions) | Active but mid-rewrite; "gameplay is basically non-functional" per own README | License-compatible-for-study |
| [OpenSAGE](https://github.com/OpenSAGE/OpenSAGE) | C# | GPL-3.0 + EA additional terms | Least active of the adjacent set; last commit 2025-12-16 | Reference-only |
| [OpenMW](https://gitlab.com/OpenMW/openmw) | C++ | GPL-3.0 | Very active, commit today | License-compatible-for-study |
| [devilutionX (diasurgical)](https://github.com/diasurgical/DevilutionX) | C++ | Sustainable Use License 1.0 (non-OSI) | Very active, commit today | Reference-only |
| [Spring](https://github.com/spring/spring) | C++ | GPL-2.0+ | Dormant, last commit 2024-03-31, issues disabled | Reference-only (superseded) |
| [Recoil (beyond-all-reason)](https://github.com/beyond-all-reason/RecoilEngine) | C++ | GPL-2.0+ | Very active, commit today; de facto successor to Spring | License-compatible-for-study |

## corepunch/open-realm

Open-realm is an MIT-licensed C reimplementation of the Warcraft III engine, verified directly from its [LICENSE file](https://github.com/corepunch/open-realm/blob/main/LICENSE) ("MIT License, Copyright (c) 2024 corepunch").
The project's owner has given libthunder's project owner explicit permission to use it as a reading reference; note that its MIT license is also permissive enough to support direct code study or adaptation beyond just reading, which is a stronger position than most other WC3-specific prior art surveyed here.
It is by far the most active project in this survey: `gh api repos/corepunch/open-realm` shows a commit on 2026-08-01 (the day of this research), 200 stars, 30 forks, and 19 open issues, with commit history running back to first real work on 2023-05-29.
Contribution is dominated by a single human author (`corepunch`, 478 commits) alongside heavy AI-agent-assisted contributions (a `Copilot` account with 103 commits and an `openhands-agent` account), and the repo ships its own `.claude/`, `AGENTS.md`, and `CLAUDE.md` files, indicating the project is itself built with AI-agent-assisted development, which is useful context when judging code-style consistency as a reading reference.
Architecturally it follows a strict Quake 2/3-style client-server split (documented in [ARCHITECTURE.md](https://github.com/corepunch/open-realm/blob/main/ARCHITECTURE.md)): all game logic runs server-side, function-table module boundaries (`R_GetAPI`, `UI_GetAPI`, game import/export tables) separate renderer/UI/game code, entity state is synchronized to clients via delta-compressed snapshots, and a loopback ring-buffer or real UDP socket carries the wire protocol depending on whether client and server share a process.
Subsystem coverage is broad for a project this size: an in-tree MPQ reader (no StormLib dependency), a full JASS lexer/parser/bytecode VM (`games/warcraft-3/jass/`: `jlex`, `jparser`, `jcode`, `jopcodes`, `jvm`), an SLK/profile "sheet" parser, an FDF UI frame-definition parser, pathing, fog-of-war, unit AI, and save/load, plus companion CLI tools (`mpqtool`, `mdxtool`, `m2tool`, `m3tool`, `dbctool`, `blp2jpg`) built into the same tree.
The project explicitly does not ship Blizzard's retail assets, scanning a user-supplied data folder for MPQ archives instead, and is organized as a reusable engine core with `games/<game>/` policy trees, currently targeting Warcraft III as the primary target with StarCraft II and World of Warcraft as secondary exploratory targets for renderer/model-loading groundwork.
Recent open issues (e.g. #106–110, DBC-driven WoW character geosets) and commit history confirm active, fine-grained ongoing development rather than a stalled prototype.

## WarSmash (Retera / WarsmashModEngine)

WarSmash is a Java/LibGDX reimplementation of the Warcraft III client, hosted at [Retera/WarsmashModEngine](https://github.com/Retera/WarsmashModEngine) — note the actual repo name is `WarsmashModEngine`, not `WarSmash`; the latter name returns a 404 on GitHub, confirmed directly during this research.
Its license is AGPL-3.0, verified by fetching the [LICENSE file](https://github.com/Retera/WarsmashModEngine/blob/main/LICENSE) content directly (full AGPLv3 text).
The repo has 548 stars, 93 forks, and 65 open issues; `main` branch's last merge was 2025-12-09, but development is real and ongoing across dozens of long-lived unmerged topic branches (e.g. one has a commit dated 2026-06-06), making its activity picture fragmented rather than cleanly "active" or "stale."
Per its own [README](https://github.com/Retera/WarsmashModEngine/blob/main/README.md), it covers MDX/M3 model rendering, terrain (cliffs, ramps, water), day/night lighting and shadows, W3X map loading and simulation, MPQ parsing (patches up to 1.29) and CASC parsing (patch 1.32.10+), BLP/DDS textures, FLAC audio, SLK/INI parsing, a `jassparser` subproject, and live client/server TCP/UDP networking; it does not support Reforged's patch 1.33+ model format.
A code search inside the repository confirmed it has no `.w3g` replay-file parser at all, despite surface hits for the word "replay" that turn out to be unrelated networking code.
Because AGPL-3.0 is a strong copyleft license, WarSmash's code cannot be adapted into libthunder without AGPL-encumbering the result, so its verdict is reference-only: useful for studying its rendering and simulation approach, not as a source of reusable code or as a `.w3g` test-pipeline tool.

## War3Net (Drake53)

War3Net is a large, MIT-licensed C# toolkit for Warcraft III file formats, hosted at [Drake53/War3Net](https://github.com/Drake53/War3Net), with the license verified directly from its [LICENSE file](https://github.com/Drake53/War3Net/blob/master/LICENSE).
It is very actively maintained: the latest commit found was 2026-08-01, the day of this research, with 1,360+ commits, 158 stars, and 37 forks.
The library is split into 20+ packages, including MPQ and CASC I/O, BLP drawing, SLK I/O, MDL text-format modeling, JASS/vJass code analysis and transpilation (to C#/Lua) plus a decompiler that reconstructs scripts from war3map files, a JASS/Lua execution engine built on NLua that reimplements Blizzard's JASS API in C#, MPQ map-archive generation from C#/vJass source, and a Veldrid-based model renderer.
Its `.w3g` replay support is notably understated by its own README, which labels `War3Net.Replay` "Coming soon™" — but the actual source under `src/War3Net.Replay/` is a real, working parser (header parsing, zlib decompression of the data-block stream, action/command/player/timeslot record types) with commits as recent as 2026-07-04, meaning the code should be trusted over the stale README claim.
Binary MDX model parsing is not in War3Net itself but pulled in via a git submodule, [Drake53/FastMDX](https://github.com/Drake53/FastMDX) (also MIT, verified via its own LICENSE file), which is itself dormant since 2020 but usable as a small reference implementation.
Given the permissive license and genuine breadth, War3Net is both license-compatible-for-study and a tool-we-can-run-in-our-test-pipeline, useful for cross-validating libthunder's own MPQ, BLP, SLK, MDX, and replay parsers, though driving it today means invoking the library directly rather than a finished CLI (the documented `w3n` CLI is not yet shipped).

## StormLib (Ladislav Zezula)

StormLib, at [ladislav-zezula/StormLib](https://github.com/ladislav-zezula/StormLib), is the de facto reference C implementation of the MPQ archive format, MIT licensed as verified from its [LICENSE file](https://github.com/ladislav-zezula/StormLib/blob/master/LICENSE).
It is actively maintained (643 stars, 249 forks, latest commit 2026-07-13, a merged community PR) and has been continuously developed since at least 2013.
Its README and documentation confirm read/write/create support for MPQ format versions 1–4 (which covers Warcraft III's MPQ format), patch-archive chains, all known internal compression codecs (zlib, bzip2, PKWARE implode, Huffman, ADPCM), listfile/attributes handling, and block encryption, with an official CMake build path for Linux.
Because it is permissively licensed, widely depended upon across the Blizzard-modding ecosystem, and directly buildable on Linux, StormLib is both license-compatible-for-study and a strong candidate as an external oracle to cross-check libthunder's own MPQ reader/writer.

## CascLib (Ladislav Zezula)

CascLib, at [ladislav-zezula/CascLib](https://github.com/ladislav-zezula/CascLib), is the companion library to StormLib for Blizzard's newer CASC storage format, MIT licensed as verified from its [LICENSE file](https://github.com/ladislav-zezula/CascLib/blob/master/LICENSE).
It is actively maintained (484 stars, 136 forks, latest commit 2026-07-21) and has been developed since 2014.
It covers local and CDN-based CASC storage reading, file enumeration and extraction, and parsing of the encoding/index/root-file formats, with a documented Linux CMake build plus Debian packaging — this is specifically the storage format used by Warcraft III: Reforged.
Like StormLib, it is both license-compatible-for-study and directly usable as a Linux-buildable test-pipeline tool, and it is the natural reference for validating a CASC reader for the modern Reforged data path.

## wc3lib (tdauth)

wc3lib, at [tdauth/wc3lib](https://github.com/tdauth/wc3lib), is a modular C++ library for Warcraft III formats, GPL-2.0 licensed as verified from its [COPYING file](https://github.com/tdauth/wc3lib/blob/master/COPYING) (full GPLv2 text).
Activity is low: a single contributor, 30 stars, and a last push of 2026-03-13, and the author's own README states the JASS and MDLX modules are "unfinished" and can be disabled via CMake options.
Its scope covers MPQ archive read/write, BLP texture read/write, a map module (TXT/SLK/TriggerData.txt), an admittedly-unfinished MDLX (model) module, an admittedly-unfinished JASS lexer/parser/AST, and a Qt-based GUI editor bundling standalone `wc3mpq`, `wc3texture`, and `wc3terrain` apps plus a combined `wc3editor`.
Its bundled JASS test fixtures include files literally named `common.j` and `Blizzard.j` (Warcraft III's real standard-library script names), which is worth flagging as a provenance caveat independent of wc3lib's own GPLv2 status if that fixture corpus is ever considered for reuse.
Given GPLv2 copyleft, low activity, single maintainership, and self-declared incompleteness in exactly the modules most relevant to libthunder, wc3lib's verdict is reference-only: its format-spec links and module boundaries are worth reading, but it is not a source of reusable code or a viable pipeline tool.

## HiveWE (stijnherfst)

HiveWE, at [stijnherfst/HiveWE](https://github.com/stijnherfst/HiveWE), is a from-scratch C++ replacement for the Warcraft III World Editor, AGPL-3.0 licensed as verified from its [LICENSE file](https://github.com/stijnherfst/HiveWE/blob/main/LICENSE).
It is the most actively maintained world-editor-focused project surveyed: 462 stars, 84 forks, 9 contributors, and a last commit of 2026-07-28, four days before this research.
Its scope is terrain, object, and pathing editing rather than a full scripting IDE: the README claims direct water-height editing, large brush sizes, doodad variation control, per-tile and global pathing-map editing, heightmap import, an "Advanced Object Editor," and substantially faster load/render times than Blizzard's own World Editor, while explicitly deferring trigger scripting and model editing to separate community tools.
Because it is AGPL-3.0, a strong copyleft that also covers network use, its code is reference-only for libthunder, but running the unmodified HiveWE binary as an external black-box tool against test maps to cross-check terrain/object/pathing round-tripping would not itself trigger copyleft obligations on libthunder's own code, making it a plausible tool-we-can-run-in-our-test-pipeline candidate for the world-editor component specifically.

## w3x2lni (sumneko)

w3x2lni, at [sumneko/w3x2lni](https://github.com/sumneko/w3x2lni), is a Lua-plus-C++ command-line and GUI tool that converts Warcraft III maps between three representations, GPL-3.0 licensed as verified from its [LICENSE.txt file](https://github.com/sumneko/w3x2lni/blob/master/LICENSE.txt).
Its author is GitHub user `sumneko` (later known for the `lua-language-server` project); no evidence was found tying the project to a "Water-Melon" account, so that attribution should be treated as unconfirmed.
Activity is moderate: 160 stars, 54 forks, 9 contributors, and a latest tagged release of 2.7.3 published 2025-12-18.
Its core function is converting a map between "Obj" (the normal binary format WE/WC3 reads), "Lni" (a lossless, version-control-friendly plain-text decomposition of the map's internal files, directly relevant to libthunder's own diffability goals), and "Slk" (a lossy, obfuscating format meant only for final distribution); it is a companion tool meant to be used alongside the real World Editor, not a replacement for it, and has no terrain/trigger/doodad editing UI of its own.
Given GPLv3 copyleft, its code is reference-only, but because it performs well-defined, lossless binary-to-text round-tripping of w3x internals, running the actual binary against test maps and diffing its Lni output against libthunder's own parser is a plausible test-pipeline use, subject to confirming it can run on Linux at all: its documentation and release artifacts reference `.exe` binaries, suggesting Windows-first distribution that would need Wine or a from-source Linux build to use in a Linux-first CI pipeline.

## mdx-m3-viewer (flowtsohg)

mdx-m3-viewer, at [flowtsohg/mdx-m3-viewer](https://github.com/flowtsohg/mdx-m3-viewer), is a TypeScript library of format parsers plus a WebGL viewer for Warcraft III and StarCraft II model/map formats, MIT licensed as verified from its [LICENSE file](https://github.com/flowtsohg/mdx-m3-viewer/blob/master/LICENSE).
Its own [README](https://github.com/flowtsohg/mdx-m3-viewer/blob/master/README.md) opens with the words "NO LONGER ACTIVELY MAINTAINED," confirmed directly during this research by fetching the raw README; the last GitHub commit was 2025-08-27, and the npm-published package (`5.12.0`, from 2021-10-23) is even more stale than the GitHub HEAD (`5.13.0`), meaning any pipeline use should vendor a pinned GitHub commit rather than track npm.
Despite being unmaintained, it is the most format-parsing-complete of the adjacent WC3 tooling projects surveyed: independent, browser-independent parsers exist for MDX/MDL (read/write, "almost everything should work"), M3 (partial), W3M/W3X/W3N (read/write, including internal files), BLP1, INI, SLK, MPQ1 (read/write), DDS, and TGA, plus a unit tester that compares rendered output against stored images and a dedicated "MDX sanity test" utility.
Given the permissive MIT license, it is both license-compatible-for-study (code and format-handling approach can be read and adapted directly) and a strong tool-we-can-run-in-our-test-pipeline candidate: it can run headlessly under Node to parse the same MDX/BLP/W3X/MPQ/SLK fixtures libthunder parses and diff results against libthunder's own output, as long as the "unmaintained" status is treated as a reason to pin a specific commit rather than assume upstream will fix newly discovered bugs.

## pjass

pjass is a JASS2 syntax and type checker, historically written by Rudi Cilibrasi and PitzerMike; the actively maintained fork is [lep/pjass](https://github.com/lep/pjass), confirmed via its own [AUTHORS file](https://github.com/lep/pjass/blob/master/AUTHORS) (listing Cilibrasi, AIAndy, PitzerMike, Deaod, Zoxc, then `lep`) and BSD-2-Clause licensed as verified from its [LICENSE file](https://github.com/lep/pjass/blob/master/LICENSE).
It is actively maintained today, with a last commit of 2026-06-15, and is still distributed as a drop-in replacement for Blizzard's own bundled `pjass.exe` in modern JASS-modding toolchains.
A check for an alternative fork by GitHub user `ChiefOfGxBxL` (mentioned as a possible lead) found that account maintains a different, custom JASS-like tooling project (`Ice-Sickle`), not a pjass fork.
Because it is a small, fast, permissively licensed native binary purpose-built to validate JASS/vJass syntax, pjass's clearest verdict is tool-we-can-run-in-our-test-pipeline: an excellent syntax-validation oracle to run alongside libthunder's own JASS/vJass parser and diff accept/reject behavior on a shared corpus of `.j` files.

## WurstScript

WurstScript, at [wurstscript/WurstScript](https://github.com/wurstscript/WurstScript), is a statically typed Java-implemented compiler for a higher-level language that compiles down to JASS or Lua for Warcraft III map scripting, Apache-2.0 licensed as verified from its [LICENSE file](https://github.com/wurstscript/WurstScript/blob/master/LICENSE).
It is very actively maintained, with 245 stars, 32 open issues, and a commit on 2026-08-01, the day of this research, from an official GitHub organization.
It bundles a compiled (binary-only) copy of Vexorian's original JassHelper and pjass under `Wurstpack/vexorianjasshelper/` as its legacy JASS-emission backend, alongside a VS Code plugin and a companion standard-library repo.
Given the permissive Apache-2.0 license, it is license-compatible-for-study, and secondarily useful as a tool-we-can-run-in-our-test-pipeline in the sense of generating real-world, syntactically valid JASS test corpora by compiling Wurst source down to JASS, rather than as a semantics oracle for JASS itself.

## vJass and JassHelper

No single dominant, community-wide-cited fork of Vexorian's original vJass compiler ("JassHelper") exists on GitHub the way `lep/pjass` does for pjass.
The closest verified match is [shuen4/jasshelper](https://github.com/shuen4/jasshelper), a Pascal/Delphi project, zlib licensed as verified from its [LICENSE.txt file](https://github.com/shuen4/jasshelper/blob/master/LICENSE.txt) (attributed to "Víctor Hugo Solíz Kúncar (Vexorian), 2006").
Its own README states this is literally Vexorian's original JassHelper source, recovered from a HiveWorkshop community thread since Vexorian never published it on GitHub himself, and it is actively maintained by a single person, with a last commit of 2026-06-07; the maintainer has flagged their own uncertainty about strict zlib-license section-2 compliance regarding the repo/binary naming, a minor provenance wrinkle worth being aware of.
The `WarRaft` GitHub organization separately maintains documentation-only resources (`WarRaft/JassHelper-manual`) and tree-sitter grammars for JASS, vJass, and Zinc, which are useful grammar references for building a parser even though they contain no compiler implementation.
Given the permissive zlib license, shuen4/jasshelper is license-compatible-for-study, and could be a tool-we-can-run-in-our-test-pipeline as a vJass-desugaring semantics oracle, though being a Windows Pascal/Delphi codebase means running it on Linux requires either Wine or a Free Pascal port.

## JASS interpreters and VMs (non-Blizzard)

This category is genuinely sparse.
[hackwaly/jass2](https://github.com/hackwaly/jass2) is a small, MIT-licensed (verified from its [LICENSE file](https://github.com/hackwaly/jass2/blob/master/LICENSE)) OCaml tree-walking JASS2 interpreter, described by its own author as "for exercise purpose"; it is abandoned, with a last commit of 2020-04-02, and GitHub's language detector mislabels the repo "Objective-J" due to its bundled `.j` sample files, though the actual source is unambiguous OCaml.
`jass_interpreter`/`jass2_interpreter` (published on [PyPI](https://pypi.org/project/jass-interpreter/), source at [Bitbucket](https://bitbucket.org/Waffle_est/jass2_interpreter)) is a "very-much half baked" (author's own description) JASS2-to-Python-3.4 cross-compiler; its PyPI metadata reports license `UNKNOWN` with no license file found anywhere, and it is dead, last updated 2015-06-20.
JiffyJass is the most functionally complete non-Blizzard JASS runtime found, distributed only as a closed-source Windows binary attachment on a [HiveWorkshop forum thread](https://www.hiveworkshop.com/threads/jiffyjass-standalone-jass-interpreter.326548/) (posted 2020-08-14, last binary update 2020-12-15, thread now closed), with no public source repository, no stated license, and a documented set of deliberate semantic divergences from Blizzard JASS (no octal literals, zero-initialized globals, order-independent declarations, Euclidean modulo, first-class functions, user-defined structs).
Two other projects surfaced but were excluded as out of scope for this category (`ScriptHookWar3`, `MemHackAPI`) because they execute JASS inside the real Blizzard game process via memory injection rather than being standalone interpreters.
All three genuine finds in this category are reference-only: hackwaly/jass2 is too small and stale to trust as an oracle despite its permissive license, the Python cross-compiler has no verifiable license at all, and JiffyJass is closed-source, unlicensed, Windows-only, and knowingly diverges from real JASS semantics.

## .w3g replay parsers

The strongest standalone replay parser is [PBug90/w3gjs](https://github.com/PBug90/w3gjs), a TypeScript library, MIT licensed as verified from its [LICENSE file](https://github.com/PBug90/w3gjs/blob/master/LICENSE), actively maintained with a last commit of 2026-04-29, offering both a high-level melee-analysis API (APM, build orders) and low-level access to individual replay blocks, though it notes incomplete support for replays from patch 1.14 and earlier.
[jblanchette/wc3v](https://github.com/jblanchette/wc3v) is a very actively maintained (last commit 2026-07-31, the day before this research) JavaScript in-browser replay viewer with its own independently written parser (confirmed not to depend on w3gjs, via its `package.json`), GPL-3.0 licensed as verified from its [LICENSE.md file](https://github.com/jblanchette/wc3v/blob/master/LICENSE.md), adding 3D map/glTF rendering and build-order visualization on top.
[scopatz/w3g](https://github.com/scopatz/w3g) is an unmaintained (last commit 2020-10-23) but historically popular Python parser, CC0-1.0 licensed (public-domain equivalent, verified via GitHub's license API), predating several patches so Reforged-era replay format changes should be checked before relying on it.
Several other parsers were found and are worth naming but are reference-only due to being dead and/or unlicensed: [aesteve/w3rs](https://github.com/aesteve/w3rs) (Rust, no license file, author's own README says "should I use it? Certainly not"), [HydraOrc/w3g](https://github.com/HydraOrc/w3g) (CoffeeScript, MIT, dead since 2018, a Node port of the historical PHP "w3g-julas" reference parser by Juliusz Gonera), and small dead PHP/Perl parsers with no license files.
Because w3gjs, wc3v, and scopatz/w3g are three independently written parsers under three different (but each usable) licenses, all three are tools-we-can-run-in-our-test-pipeline: running them side by side against the same replay corpus and diffing their output against libthunder's own decoder gives triangulated confidence rather than relying on a single external oracle.

## Other WC3 engine reimplementation attempts

No other actively maintained or historically significant full-engine reimplementation attempt was found beyond the three already covered in this survey (corepunch/open-realm, WarSmash/WarsmashModEngine, and War3Net).
Two other GitHub repos that looked promising in search results, `game-a11y/OpenWarcraft3` and `fuwujiaxx/openwt3`, were checked via `gh api` and confirmed to be plain unmodified forks of `corepunch/open-realm` (`fork: true`, `parent: corepunch/open-realm`), not independent projects.
The curated clone-tracking site [osgameclones.com/warcraft-iii](https://osgameclones.com/warcraft-iii/) lists only HiveWE (a world-editor tool, not a full engine) and WarsmashModEngine among Warcraft III clones, corroborating the small size of this field.
This search used GitHub's search API, GitHub topic pages, and the osgameclones directory; it did not exhaustively cover non-GitHub hosts (SourceForge, GitLab, self-hosted git, private/unlisted repos) beyond what surfaced in general web search, so the honest claim is "no additional project found in this search," not "no other project exists."
This is a genuinely small field: unlike Age of Empires II (openage), Command & Conquer (OpenRA, OpenSAGE), or Morrowind (OpenMW), Warcraft III has no larger established open-source reimplementation community for libthunder to join instead of starting fresh, and no crowded field to differentiate from either.

## OpenRA

OpenRA, at [OpenRA/OpenRA](https://github.com/OpenRA/OpenRA), reimplements Westwood's engine underlying Red Alert, Tiberian Dawn, and Dune 2000, GPL-3.0 licensed as verified from its [COPYING file](https://github.com/OpenRA/OpenRA/blob/bleed/COPYING).
It is the most starred project in this entire survey (17,163 stars, ~445 contributors) and very actively maintained, with a last commit of 2026-07-23.
Architecturally, gameplay content is defined through a YAML-driven "trait" composition system rather than code-level inheritance, with a Lua API for scripted missions, SDL/OpenGL rendering, and a full in-game map editor with undo/redo and actor-property editing, all supporting an official Mod SDK for independent total conversions.
As C# code under GPL-3.0, it is license-compatible-for-study rather than a source of directly portable code for an Odin project, but its YAML-driven data model and bundled map editor are directly relevant architectural patterns for libthunder's object-data and world-editor design; it is not a candidate test-pipeline tool since its file formats (MIX, SHP) are unrelated to Warcraft III's.

## openage

openage, at [SFTtech/openage](https://github.com/SFTtech/openage), reimplements the Genie Engine underlying Age of Empires I/II, with a C++20 engine core plus Python used for scripting, asset conversion, and code generation.
Its license is GPL-3.0-or-later for the great majority of the codebase, with a small, explicitly enumerated set of exceptions (an LGPL-2.0 compression file from libmspack, two BSD-3-Clause CMake find-modules) documented in [copying.md](https://raw.githubusercontent.com/SFTtech/openage/master/copying.md); GitHub reports the license as "Other" only because this file isn't in standard SPDX format, not because the license is unusual.
It is active (last commit 2026-07-04) but by its own README's admission is mid-rewrite of its core simulation layer, with the caveat "gameplay is basically non-functional" as of the current README.
Architecturally it uses an entity-component model with ability/modifier components and a node-based action-flow graph, and content/modding is defined in `nyan`, a custom data language purpose-built for the project; critically, it never ships original game assets, instead requiring the user to own AoE1/AoE2 and shipping a separate `media_convert` pipeline that extracts and converts assets from the user's own install at build/run time, with a companion `openage-data` project providing freely licensed replacement assets.
This asset pipeline model, "bring your own copyrighted game, convert its assets locally, ship nothing proprietary," is the single most directly relevant architectural pattern of any adjacent project surveyed for how libthunder should handle real Warcraft III assets, even though openage's actual format parsers target unrelated Genie-engine files.

## OpenSAGE

OpenSAGE, at [OpenSAGE/OpenSAGE](https://github.com/OpenSAGE/OpenSAGE), is an early-stage C# reimplementation of EA's SAGE engine, targeting Command & Conquer: Generals and Zero Hour.
Its licensing is two-tier: OpenSAGE's own code is GPL-3.0, but portions "ported from EA's Command & Conquer Generals and Command & Conquer Generals Zero Hour source code" (which EA itself released under GPLv3 with additional terms in 2013) are governed by a separate [LICENSE-EA.md](https://raw.githubusercontent.com/OpenSAGE/OpenSAGE/master/LICENSE-EA.md), whose extra terms forbid claiming EA affiliation and require indemnifying EA under certain conditions; OpenSAGE's own license file explicitly warns this EA license is "the most restrictive" and the one to pay attention to.
It is the least active project in the adjacent-projects set surveyed, with its last commit to `master` dated 2025-12-16, roughly 7.5 months before this research, and its own README roadmap checklist shows scripting, most rendering, AI, physics, and networking still unimplemented.
Its most useful contribution to libthunder is not code but stated methodology: its README explicitly frames the project as "blackbox re-implementation," writing code "based on reading data files, and observing the game running," and its contribution policy explicitly states "no code that was acquired through reverse engineering executable binaries will be accepted" — a clean, citable precedent for a clean-room posture libthunder could adopt and document, independent of OpenSAGE's own immaturity as a codebase to study.

## OpenMW

OpenMW's canonical repository is on GitLab at [gitlab.com/OpenMW/openmw](https://gitlab.com/OpenMW/openmw); the GitHub repo is an explicit read-only mirror (GitHub Issues disabled, README points to GitLab for the real issue tracker).
It is GPL-3.0 licensed, verified directly from its [LICENSE file](https://gitlab.com/OpenMW/openmw/-/raw/master/LICENSE), with a couple of bundled UI fonts under separate compatible licenses.
Via the GitHub mirror's commit history it is extremely active, with a commit on 2026-08-01, the day of this research, and roughly 501 contributors over its history since 2009.
Its scope includes a full engine reimplementing Morrowind plus its expansions, and its own from-scratch world editor, OpenMW-CS, explicitly described as "a replacement for Bethesda's Construction Set," alongside a family of small standalone format-inspection tools in the same repo (`esmtool`, `bsatool`, `niftest`) that the OpenMW community uses as both diagnostic CLIs and independent fuzz-testing targets.
Its asset/IP handling model is the clearest and most explicitly documented of any project surveyed: the README states plainly "you need to own the game for OpenMW to play Morrowind," the project's own FAQ clarifies its ESM/ESP/BSA loading code "was written from scratch, but with much help from available community-generated documentation" rather than from Bethesda's binary or source, and enforcement is entirely social and procedural (a `--data`/`--data-local` path plus an install-detection "wizard" app that finds or imports the user's existing legitimate install), not any form of DRM.
For libthunder, the most transferable idea from OpenMW is not any specific code (Morrowind's NIF/ESM/BSA formats are unrelated to Warcraft III's MPQ/MDX/BLP) but its architectural pattern of decoupling per-format parsers into small, independently testable, independently fuzzable standalone binaries alongside the main engine, plus its citable "written from scratch against documentation" clean-room methodology statement.

## devilutionX

devilutionX, at [diasurgical/DevilutionX](https://github.com/diasurgical/DevilutionX), is a modernized C++ port and rewrite carrying forward the Diablo (and later Hellfire) codebase, and is very actively maintained, with a commit on 2026-08-01, the day of this research, 9,649 stars, and roughly 282 contributors.
Its license is the Sustainable Use License, Version 1.0, verified directly from its [LICENSE.md file](https://raw.githubusercontent.com/diasurgical/DevilutionX/master/LICENSE.md); this is not an OSI-approved open-source license, restricting use to "your own internal business purposes or for non-commercial or personal use" and permitting redistribution only free of charge for non-commercial purposes — a deliberate relicense dated to a 2022-08-26 commit, corroborated independently by a [NixOS/nixpkgs issue](https://github.com/NixOS/nixpkgs/issues/366048) flagging the switch from a more permissive earlier license; no public maintainer statement explaining the rationale for the change was found in the time available, so that specific "why" is unverified.
Its origin story is categorically different from OpenMW's or OpenSAGE's stated clean-room methodology: devilutionX's own predecessor project, [galaxyhaxz/devilution](https://github.com/galaxyhaxz/devilution), describes itself in its own README as built by decompiling the original DOS binary, with its first version explicitly "a raw dump from IDA" (a disassembler) that was then manually fixed until it compiled, rather than code written independently from documentation or observed behavior.
Like every other adjacent project surveyed, it ships no game data and requires the user to supply their own legitimately-owned `DIABDAT.MPQ` (or a shareware `spawn.mpq`).
Given the non-OSI, non-commercial license and the disassembly-derived (not clean-room) origin of its underlying codebase, devilutionX's verdict for libthunder is reference-only, useful mainly as a case study in community organization and multi-platform porting, and as a cautionary contrast to OpenMW/OpenSAGE if libthunder wants to make a defensible clean-room claim of its own.

## Spring / Recoil

The original Spring RTS engine, at [spring/spring](https://github.com/spring/spring), is effectively dormant: its last commit was 2024-03-31, over two years before this research, and its GitHub Issues are disabled in favor of a legacy tracker.
Its actively maintained successor is [beyond-all-reason/RecoilEngine](https://github.com/beyond-all-reason/RecoilEngine) (formerly named `beyond-all-reason/spring`, confirmed by the old URL 301-redirecting to the new one), whose own README states plainly "Recoil is a fork and continuation of [Spring] version 105.0"; as of this research Recoil is very active, with a commit on 2026-08-01, 646 stars, and roughly 250 contributors, making it the de facto successor rather than a parallel project.
Both are GPL-2.0-or-later licensed, verified by fetching identical LICENSE text from both repositories.
Architecturally, both engines separate simulation/rendering from an extensive Lua-scripted game-logic layer, with a documented split between "synced" Lua (deterministic, must produce identical results on every client for lockstep multiplayer) and "unsynced" Lua (client-local rendering/UI/input); a legacy COB unit-animation scripting system is being phased out in favor of Lua unit scripts, and neither engine ships its own first-party map/world editor, relying instead on external community tooling.
Given the permissive-for-a-C++-project GPL-2.0+ license and closer language pairing to a native Odin engine than the C#-based projects surveyed, Recoil is license-compatible-for-study, and its synced/unsynced Lua determinism split is a directly relevant architectural reference for any lockstep-multiplayer RTS engine, Warcraft III included, given JASS's similar role as WC3's in-game scripting layer.

## Lessons for libthunder

Every adjacent reimplementation project surveyed (OpenMW, openage, OpenSAGE, OpenRA, devilutionX) follows the same asset/IP pattern: ship no copyrighted game data, require the user to supply their own legitimately owned copy, and load it from a configurable data path, with enforcement handled socially and procedurally (documentation, an install-detection wizard) rather than through any DRM; corepunch/open-realm already follows this same ScummVM-style model for Warcraft III, so it is a validated approach worth continuing rather than reinventing.
There is a real, citable distinction in the field between clean-room-from-documentation methodology (OpenMW's "written from scratch... with much help from available community-generated documentation," OpenSAGE's explicit ban on reverse-engineered-binary contributions) and decompilation-derived methodology (devilutionX's predecessor project self-describing its first version as "a raw dump from IDA"); if libthunder wants a defensible clean-room posture, OpenMW's and OpenSAGE's stated methodology and contribution policy are the precedents to cite and adopt, and devilutionX's lineage is the pattern to explicitly avoid.
corepunch/open-realm's Quake 2/3-style client-server split, with function-table module boundaries between renderer/UI/game and delta-compressed entity-state snapshots, is a proven, thoroughly documented architecture directly applicable to libthunder, and is worth close reading precisely because it is our explicitly authorized reading reference and already targets the same file formats and gameplay systems.
Spring/Recoil's synced/unsynced Lua split is a relevant architectural reference for how JASS's role in WC3 gameplay determinism could be modeled if libthunder needs deterministic lockstep multiplayer; openage's entity-component-plus-external-data-language (`nyan`) model is worth studying for an object/ability data model analogous to WC3's object editor tables, even though openage's own gameplay layer is currently non-functional mid-rewrite.
For a round-trip test pipeline, several permissively licensed, actively maintained tools can serve as external cross-validation oracles even where their code cannot be reused: StormLib and CascLib for MPQ/CASC archive round-tripping, pjass for JASS/vJass syntax validation, War3Net and mdx-m3-viewer for MPQ/BLP/SLK/MDX/W3X parsing (mdx-m3-viewer should be pinned to a specific GitHub commit rather than tracked via its stale npm package, given its self-declared unmaintained status), and w3gjs, wc3v, and scopatz/w3g together as three independently written `.w3g` replay parsers whose outputs can be triangulated against each other and against libthunder's own decoder; HiveWE and w3x2lni are plausible black-box binary test tools for the world-editor component specifically, subject to confirming Linux-runnability for w3x2lni and understanding that running an AGPL/GPL binary unmodified as an external test tool does not itself create copyleft obligations on libthunder's own code (this is not legal advice and should be sanity-checked before being relied on).
This research also surfaced two general due-diligence lessons worth carrying forward: several projects' README claims did not match their actual code state (War3Net's replay parser is real despite a "coming soon" label; WarSmash's `main` branch looks stale while unmerged feature branches show much more recent activity) which is a reminder to verify claims against source and commit history rather than documentation alone, and the WC3-specific reimplementation field itself is very small: after excluding plain forks, no full-engine reimplementation attempt beyond corepunch/open-realm, WarsmashModEngine, and War3Net was found, so libthunder is entering a nearly empty field rather than a crowded one.
The license landscape splits cleanly along a boundary: WC3-specific engine/editor-scope projects skew copyleft (WarSmash and HiveWE are AGPL-3.0, wc3lib and w3x2lni are GPL-2.0/3.0), while the general-purpose format/tooling layer skews permissive (StormLib, CascLib, War3Net, mdx-m3-viewer are MIT; pjass is BSD-2-Clause; WurstScript is Apache-2.0; the vJass compiler recovery is zlib) — corepunch/open-realm's MIT license is a notable exception among the WC3-specific, engine-scope projects, which reinforces its value to libthunder as more than just a reading reference.

## Sources

### corepunch/open-realm
- https://github.com/corepunch/open-realm
- https://github.com/corepunch/open-realm/blob/main/LICENSE
- https://github.com/corepunch/open-realm/blob/main/README.md
- https://github.com/corepunch/open-realm/blob/main/ARCHITECTURE.md
- https://github.com/corepunch/open-realm/blob/main/TODO.md
- https://github.com/game-a11y/OpenWarcraft3 (confirmed fork of corepunch/open-realm)
- https://github.com/fuwujiaxx/openwt3 (confirmed fork of corepunch/open-realm)
- `gh api repos/corepunch/open-realm` (metadata: stars, forks, issues, license, dates)
- `gh api repos/corepunch/open-realm/commits`
- `gh api repos/corepunch/open-realm/contributors`
- `gh api repos/corepunch/open-realm/contents` (and subpaths: `games/warcraft-3`, `games/warcraft-3/game`, `games/warcraft-3/jass`, `tools`)
- `gh api repos/corepunch/open-realm/issues`
- `gh api repos/corepunch/open-realm/forks`

### WarSmash / War3Net / StormLib / CascLib
- https://github.com/Retera/WarsmashModEngine
- https://github.com/Retera/WarsmashModEngine/blob/main/LICENSE
- https://github.com/Retera/WarsmashModEngine/blob/main/README.md
- `gh api repos/Retera/WarsmashModEngine` (and `/license`, `/commits`, `/branches`, `/contents`)
- `gh api "search/code?q=repo:Retera/WarsmashModEngine+w3g"`
- `gh api "search/code?q=repo:Retera/WarsmashModEngine+replay"`
- https://github.com/Drake53/War3Net
- https://github.com/Drake53/War3Net/blob/master/LICENSE
- https://github.com/Drake53/War3Net/blob/master/README.md
- `gh api repos/Drake53/War3Net` (and `/license`, `/commits`, `/contents`, subpaths `src`, `src/War3Net.Replay`)
- https://github.com/Drake53/FastMDX
- https://github.com/Drake53/FastMDX/blob/master/LICENSE
- https://github.com/ladislav-zezula/StormLib
- https://github.com/ladislav-zezula/StormLib/blob/master/LICENSE
- https://github.com/ladislav-zezula/StormLib/blob/master/README.md
- https://github.com/ladislav-zezula/CascLib
- https://github.com/ladislav-zezula/CascLib/blob/master/LICENSE
- https://github.com/ladislav-zezula/CascLib/blob/master/README.md

### wc3lib / HiveWE / w3x2lni / mdx-m3-viewer
- https://github.com/tdauth/wc3lib
- https://github.com/tdauth/wc3lib/blob/master/COPYING
- https://github.com/tdauth/wc3lib/blob/master/README.md
- https://github.com/CruzR/wc3lib (self-identified mirror)
- https://github.com/stijnherfst/HiveWE
- https://github.com/stijnherfst/HiveWE/blob/main/LICENSE
- https://github.com/stijnherfst/HiveWE/blob/main/README.md
- https://github.com/sumneko/w3x2lni
- https://github.com/sumneko/w3x2lni/blob/master/LICENSE.txt
- https://github.com/sumneko/w3x2lni/blob/master/docs/en-us/README.md
- https://github.com/flowtsohg/mdx-m3-viewer
- https://github.com/flowtsohg/mdx-m3-viewer/blob/master/LICENSE
- https://github.com/flowtsohg/mdx-m3-viewer/blob/master/README.md
- https://raw.githubusercontent.com/flowtsohg/mdx-m3-viewer/master/README.md
- https://registry.npmjs.org/mdx-m3-viewer

### pjass / WurstScript / vJass / JASS interpreters / replay parsers
- https://github.com/lep/pjass
- https://github.com/lep/pjass/blob/master/LICENSE
- https://github.com/lep/pjass/blob/master/AUTHORS
- https://github.com/ChiefOfGxBxL
- https://github.com/wurstscript/WurstScript
- https://github.com/wurstscript/WurstScript/blob/master/LICENSE
- https://github.com/wurstscript/WurstScript/tree/master/Wurstpack/vexorianjasshelper
- https://github.com/shuen4/jasshelper
- https://github.com/shuen4/jasshelper/blob/master/LICENSE.txt
- https://github.com/shuen4/jasshelper/blob/master/README.md
- https://github.com/WarRaft/JassHelper-manual
- https://github.com/hackwaly/jass2
- https://github.com/hackwaly/jass2/blob/master/LICENSE
- https://pypi.org/project/jass-interpreter/
- https://pypi.org/pypi/jass-interpreter/json
- https://bitbucket.org/Waffle_est/jass2_interpreter
- https://www.hiveworkshop.com/threads/jiffyjass-standalone-jass-interpreter.326548/
- https://github.com/seven-mile/ScriptHookWar3
- https://github.com/UnryzeC/MemHackAPI
- https://osgameclones.com/warcraft-iii/
- https://github.com/PBug90/w3gjs
- https://github.com/PBug90/w3gjs/blob/master/LICENSE
- https://github.com/jblanchette/wc3v
- https://github.com/jblanchette/wc3v/blob/master/LICENSE.md
- https://github.com/scopatz/w3g
- https://github.com/aesteve/w3rs
- https://github.com/HydraOrc/w3g
- https://github.com/JFGHT/Warcraft-III-Replay-Parser-for-PHP
- https://github.com/tipdbmp/wc3-replay-parser

### OpenRA / openage / OpenSAGE / OpenMW / devilutionX / Spring / Recoil
- https://github.com/OpenRA/OpenRA
- https://github.com/OpenRA/OpenRA/blob/bleed/COPYING
- https://raw.githubusercontent.com/OpenRA/OpenRA/bleed/README.md
- https://github.com/SFTtech/openage
- https://raw.githubusercontent.com/SFTtech/openage/master/copying.md
- https://raw.githubusercontent.com/SFTtech/openage/master/README.md
- https://github.com/OpenSAGE/OpenSAGE
- https://raw.githubusercontent.com/OpenSAGE/OpenSAGE/master/LICENSE.md
- https://raw.githubusercontent.com/OpenSAGE/OpenSAGE/master/LICENSE-EA.md
- https://raw.githubusercontent.com/OpenSAGE/OpenSAGE/master/README.md
- https://gitlab.com/OpenMW/openmw
- https://gitlab.com/OpenMW/openmw/-/raw/master/LICENSE
- https://github.com/OpenMW/openmw (GitHub mirror, used for commit-activity tracking)
- https://raw.githubusercontent.com/OpenMW/openmw/master/README.md
- https://openmw.org/faq/
- https://github.com/diasurgical/DevilutionX
- https://raw.githubusercontent.com/diasurgical/DevilutionX/master/LICENSE.md
- https://raw.githubusercontent.com/diasurgical/DevilutionX/master/README.md
- https://github.com/galaxyhaxz/devilution
- https://github.com/NixOS/nixpkgs/issues/366048
- https://github.com/spring/spring
- https://raw.githubusercontent.com/spring/spring/develop/LICENSE
- https://github.com/beyond-all-reason/RecoilEngine
- https://raw.githubusercontent.com/beyond-all-reason/RecoilEngine/master/README.markdown
- https://springrts.com/phpbb/viewtopic.php?t=49691

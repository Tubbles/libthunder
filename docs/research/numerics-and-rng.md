# Simulation numerics and randomness

Research backing decision 0007 (`docs/decisions/0007-sim-numerics-f32-discipline.md`), which fixes the sim scalar at binary32 under a mechanically enforced discipline. Work item: WI-0013.

Three parallel research slices fed this document, all dated 2026-08-11: community and official knowledge of how the real 1.29b engine computes; measured behavior of the pinned Odin toolchain on the development machine plus documented behavior of the wasm and ARM targets; and a read of corepunch/open-realm at a pinned commit. The raw slice notes lived in the git-ignored `work/` directory and are superseded by this document.

Two questions are deliberately kept apart throughout. Layer 0 asks whether *our* simulation produces identical bits on every target we ship. Layer 4 asks whether our arithmetic tracks *the real engine's*. The evidence answers the first well and the second barely at all, which is why decision 0007 targets event-level replay conformance first and leaves bit-level parity to empirical oracle work under WI-0017.

## Confidence markers

- **documented**: stated by Blizzard, or by a format/API specification whose author states it was derived without reverse engineering.
- **community-consensus**: repeated independently across community sources and consistent with the format specs.
- **single-source**: one source only, plausible but unreplicated.
- **unverified**: asserted somewhere but not confirmable, or flagged as a guess by its own author.
- **derived**: a deduction from cited facts, with the deduction spelled out so it can be checked.
- **measured**: produced by a probe on the development machine, with the build command recorded here.

## Clean-room boundary and off-limits sources

The single most-cited community account of the Warcraft III pseudo-random generator is Hex-Rays decompiler output of the game executable. It is off-limits under the project's clean-room rule. The practical consequence runs through the whole RNG half of this document: **for clean-room purposes we do not know the WC3 RNG algorithm** and must derive it black box from published observations and our own oracle measurements.

These sources were identified and are recorded here so nobody re-opens them by accident:

- <https://www.hiveworkshop.com/threads/random.286109/>. The canonical community RNG thread. Its key post is Hex-Rays decompiler output including the generated banner. **Do not consult.** Note that jassdoc's `GetRandomInt` doc comment links directly to it (`http://hiveworkshop.com/threads/random.286109#post-3073222`), so anyone reading `common.j` is one click away.
- <https://bbs.kanxue.com/thread-110540.htm>. A reverse-engineering forum thread whose title asks for the `GetRandomInt` algorithm. Not fetched, not consulted, presumptively off-limits.
- <https://github.com/huntergregal/PyJASSPrng>. README only was read, for its published in-game test vectors, which are observations of the running game. The implementation source was **not** read: its provenance traces to the decompiled thread and the repository carries no licence. The same posture applies to any other RNG reimplementation.
- <https://github.com/lep/jassdoc/issues/151> is mixed. Black-box measurement in that thread is usable; one contributor's paraphrase of decompiled code is not. Both appear below with their provenance attached.

No decompiled or disassembled Blizzard code was used anywhere in this research. Everything below rests on official Blizzard pages, community-authored format specifications, community API documentation, community protocol documentation, community measurement threads, our own probes, and an MIT-licensed reference codebase.

## 1. What the real engine does

### 1.1 Floats are the interchange type of the lockstep command stream

Target coordinates inside replay command records are "standard IEEE single precision floats (4 bytes)" corresponding to World Editor coordinates, map centre at (0,0), range -16384.000 to 16384.000 for a 256x256 map. Actions 0x11, 0x12, 0x13, 0x14 and 0x68 each carry one or two such coordinate pairs, and action 0x2E carries a raw float time value. **documented**, <https://alanfox2000software.github.io/war3-diy/doc/replay/files/w3g_actions.txt>.

This is the strongest single piece of evidence in the slice, because it is about the wire format of the command stream itself: the engine accepts a raw 32-bit float from the network or replay as a simulation input. Whatever the internals are, binary32 is the interchange type for positions, so f32 enters our sim as input regardless of what we choose internally.

Blizzard describes the model in their own words: "A replay is a simulation of a previously played game, for which we store only the user interface commands that took place in the game", and "Because of the way that replays are generated, they currently cannot be viewed across game versions". **documented**, <http://classic.battle.net/war3/faq/replays.shtml>. The network model is "a variation of the peer-to-peer model" rather than client/server, <http://classic.battle.net/war3/faq/features.shtml>. jassdoc states the same from the modding side: "Warcraft 3 has the lock-step network/execution model. This means the game simulation and code run on all players' computers with the exact same data at any point in time" (`GetLocalPlayer` doc, <https://raw.githubusercontent.com/lep/jassdoc/master/common.j>). The community tutorial adds that every player runs the full simulation, only inputs are exchanged, and on divergence with more than two players the minority group is presumed wrong and kicked, <https://www.hiveworkshop.com/threads/explaining-warcrafts-lockstep-architecture-for-mapping-avoid-desyncs.351561/>.

### 1.2 JASS `real` is binary32

The JASS manual is honest about its own uncertainty: "One assumes the values are 32-bit and conform to the IEEE Standard 754 Floating-Point standard (someone want to verify this?)". **community-consensus**, <https://jass.sourceforge.net/doc/types.shtml>. The same manual gives the integer range as -2147483647..2147483647, one off from the actual two's-complement minimum; jassdoc's `GetRandomInt` bug note uses the correct -2147483648.

**derived** confirmation: jassdoc records a measured in-game print of `GetRandomReal(0, 50)` at 16 decimal places as `49.9999580383300781`. That value round-trips exactly through IEEE binary32, sitting exactly 11 ULP below 50.0 on the binary32 grid. A double-precision engine would essentially never print a value that lands exactly on that grid. Measurement source: <https://raw.githubusercontent.com/lep/jassdoc/master/common.j>, originating from <https://github.com/lep/jassdoc/issues/151#issuecomment-2177178728>.

### 1.3 Reals cross into authoritative state

jassdoc's `@async` annotation system exists because most natives are synchronous. Real-valued natives that mutate or read sim state and are **not** marked async include `SetUnitX`/`SetUnitY`, `GetUnitState` with `UNIT_STATE_LIFE` and `UNIT_STATE_MANA`, `GetUnitFacing`, `BlzGetUnitArmor`/`BlzSetUnitArmor` (which accepts negative reals), and the whole `unitweaponrealfield` family: attack range, base cooldown, projectile speed and arc, damage loss factor, damage factor medium and small, area-of-effect damage fractions, spill distance and radius. `UnitDamageTarget` takes a real amount and `GetEventDamage` returns a real. **documented**, <https://raw.githubusercontent.com/lep/jassdoc/master/common.j>.

The complementary integer set is equally sharp. Base attack damage is an integer dice roll: `UNIT_WEAPON_IF_ATTACK_DAMAGE_BASE`, `..._NUMBER_OF_DICE` and `..._SIDES_PER_DIE` are all `unitweaponintegerfield` with matching integer natives `BlzGetUnitDiceNumber`/`BlzGetUnitDiceSides`, so the pre-mitigation roll is `base + sum of N rolls of 1..S` entirely in integers, consuming N draws from the RNG per attack. Bounty has the same shape. Player gold, lumber and food are integers via `GetPlayerState`. Armor types, attack types, unit type ids, levels and ability level fields are integers. **documented**, same source.

So the roll is integer, the mitigation is real, and the resulting hit-point subtraction is real. No community source found claims the engine rounds damage to an integer before applying it, and the displayed damage numbers are rounded for presentation. This is an absence of evidence, not evidence of absence: experiment O-5 settles it.

### 1.4 The authoritative simulation is 2D; Z is renderer-derived

jassdoc on `BlzGetUnitZ`: "Terrain height is not synced between clients in multiplayer, because it relies on ray intersection of the to-be-rendered visuals (sprites). Operating on Z values will lead to desyncs if something beyond visuals is affected." `GetLocationZ` carries the same `@async` marker plus: "Reasons for returning different values between players might be terrain-deformations caused by spells/abilities and different graphic settings." **documented**, <https://raw.githubusercontent.com/lep/jassdoc/master/common.j>.

Architecturally this says the authoritative simulation is 2D in XY, and Z is a renderer-derived quantity computed by ray-casting against the visual mesh, outside the lockstep contract. Decision 0007 adopts this directly. It removes terrain interpolation and model geometry, a whole class of float-determinism risk, from the sim.

### 1.5 Coordinate quantization

Unit positions are continuous binary32 (1.1, 1.2), but the pathing world is quantized. The pathing map is one flag byte per cell at 32 world units per cell ("Each pixel in the TGA file represents 32 grid units in the editor", <https://world-editor-tutorials.thehelper.net/pathmaps.php>) **community-consensus**. The claim that collision size is expressed in those cells (a unit with collision size 2 needing a 2x2 block of free path nodes) is **unverified**: it is not in the pathmaps tutorial and no citation was found; it is oracle-map territory. The 128-units-per-tile figure for the terrain grid is likewise **unverified** here (grounding review 2026-08-11: `docs/research/file-formats.md` carries no such figure and marks the cell-to-tilepoint ratio unverified); what file-formats.md does corroborate is the shadow map sampling 4x4 per tile. What WI-0010 pinned empirically is the structural ratio: 4 pathing cells per terrain tile edge, both grids keyed to tiles. Continuous float positions tested against an integer 32-unit occupancy grid: any quantization scheme we adopt should make the cell and tile grids exactly representable, with the world-unit sizes confirmed by oracle before being relied on.

### 1.6 The original build cannot have used SSE

Blizzard's published minimum specification is a "400 MHz Pentium II or equivalent" on Windows and a "400 MHz G3 processor" on Mac. **documented**, <http://classic.battle.net/war3/faq/features.shtml>. **derived**: the Pentium II predates SSE entirely (SSE arrived with the Pentium III), so a binary that runs on one does its floating-point work on the x87 stack, with 80-bit internal registers, precision governed by the FPU control word, and no FMA. That is the 2002 engine's FP semantics.

The G3 minimum means the same simulation also shipped on big-endian PowerPC with a very different FPU. Whether Mac and Windows clients could ever share a Battle.net or LAN game could not be established; repeated searches found no authoritative statement either way. The answer is highly informative and is listed as an open question below: if they could, the 2002 engine achieved bit-identical results across two radically different FPUs, which implies deliberate discipline rather than luck.

Whether the 1.29-era rebuild (2018 toolchain, still shipping a Windows XP-compatible client per <https://warcraft.wiki.gg/wiki/Warcraft_III/Patch_1.29.0>) emits x87 or SSE2 is **unverified** and cannot be settled without disassembly, which is off-limits. It is also mostly irrelevant: what matters is the observable arithmetic, which is what WI-0017 measures.

### 1.7 Negative armor uses an exponential

Blizzard's own page gives, for positive armor, `damage reduction = ((armor)*0.06)/(1+0.06*(armor))`, and for negative armor, `damage increase = 2 - 0.94^(-armor)`. **documented**, <http://classic.battle.net/war3/basics/armorandweapontypes.shtml>. The 0.06 constant is exposed to map authors as the "Combat - Armor Damage Reduction Multiplier" gameplay constant, so the formula is genuinely evaluated rather than baked into a per-armor table (**community-consensus**, the constant is editable in the World Editor).

This is the worst finding in the slice for bit-exact portability. `pow` is not IEEE-specified, it is libm-dependent, and it sits in the sync-critical damage path. `BlzGetUnitArmor` returns a real, so the exponent is not restricted to integers. Whether the engine calls a true `pow`, an `exp`/`log` pair, a repeated-multiply loop over integer armor, or a lookup table is **unverified**; experiment O-8 discriminates between them by residual pattern. Decision 0007's requirement that every non-basic function come from our own `simmath` package exists precisely so this formula has one implementation everywhere, whose output can then be compared against oracle measurements.

### 1.8 The RNG API contract

From jassdoc's doc comments, all describing observed behavior. **documented**, <https://raw.githubusercontent.com/lep/jassdoc/master/common.j>:

- `GetRandomInt(low, high)` returns an integer in `[low, high]`, inclusive at both ends; when `low == high` it always returns that number.
- `GetRandomReal(low, high)` returns a real in `[low, high)`, inclusive low and **exclusive high**; when `low == high` it always returns that number. Consistent with the 49.9999580383300781 measurement in 1.2.
- `SetRandomSeed(seed)` takes a single 32-bit integer and makes the sequence repeatable. Worked example: `SetRandomSeed(42)` then `GetRandomInt(0, 18)` yields 12, then 2; re-seeding with 42 yields 12 again.
- Bug: `GetRandomInt(INT_MIN, INT_MAX)` or `GetRandomInt(INT_MAX, INT_MIN)` always returns the same value (`INT_MIN` or `INT_MAX` respectively).
- All three natives carry "**Desyncs!** The random number generator is a global, shared resource. Do not change its state in local blocks asynchronously." That is a direct statement that the PRNG is a single global stream shared by the entire simulation, not per-system or per-unit.
- The World Editor exposes a "fixed seed" test-map option, so seeding is a first-class capability.

For reversed bounds (`low > high`), two contributors converged by measurement on: `min = low`, `mid = low + delta/2`, `max = low + delta` where `delta = |high - low|`. `GetRandomInt` effectively swaps reversed bounds; `GetRandomReal` does not, mirroring the interval upward from `low` instead. The contributor who wrote it up states he abandoned pseudocode and "found it easier to go off generated values". **community-consensus**, <https://github.com/lep/jassdoc/issues/151#issuecomment-2143869913>, <https://github.com/lep/jassdoc/issues/151#issuecomment-2177178728>, <https://github.com/lep/jassdoc/issues/151#issuecomment-2177306404>.

One claim from the same thread has mixed provenance and must not be used as given: that `GetRandomReal` builds a float in `[1.0, 2.0)` by filling the binary32 mantissa and forcing the exponent to `0x3F800000`, then returns `low + delta * (random - 1)`. It was stated by a contributor paraphrasing decompiled code. It is a standard technique and it is trivially testable black box, so it is a fine hypothesis for O-3 to confirm or refute from measurements, and nothing more.

### 1.9 Published black-box test vectors

A community Python reimplementation publishes side-by-side output. Real Warcraft III output for `SetRandomSeed(12345)` followed by three calls to `GetRandomInt(0, 1000000)` is **189832, 638801, 925099**. **single-source but directly reusable**, <https://github.com/huntergregal/PyJASSPrng> (README only; see the off-limits register).

The same README publishes reals for the same seed, initially recorded by this research as internally inconsistent (two disagreeing numbers per call). The grounding review re-read the upstream README directly (2026-08-11) and resolved it: the README's JASS test script calls `GetRandomReal` separately for each of two display lines, so the pairs are consecutive draws, not one value transcribed twice. All six reals are therefore usable as consecutive-draw vectors: after the three integer draws under seed 12345, draws four through nine are 2.566 and 4.405078400 (bounds 2.245..6.532), 1.568 and 1.275389408 (bounds 1.1..2.5), and -0.997 and 0.035798548 (bounds -2.1..3.14), at the printed precisions. **single-source but directly reusable**, same citation as the integers.

What does carry from that source regardless: its author reports his reimplementation matches the integers exactly but differs from the game on the reals by roughly 25 ULP. Bit-exact `GetRandomReal` is not a solved problem even for people working from the decompiled structure.

### 1.10 The RNG may not be stable across patches

A contributor reports that `SetRandomSeed(10)` then `GetRandomInt(0, 100)` gives **55 on patch 1.31**, while a Python implementation written against 1.29.2 gives **43**, and speculates that "the implementation was changed at some point" between 1.29.2 and the 1.31 PTR. **single-source**, <https://www.hiveworkshop.com/threads/warcraft3-random-implementation.327901/> (that thread contains no decompiler output itself, though it links to the off-limits thread).

This is the most consequential RNG finding after the clean-room block. Any RNG oracle work must be done against a 1.29.2 client specifically, and vectors harvested from 1.31 or later, or from Reforged, are not authoritative for our parity target.

### 1.11 Pseudo Random Distribution

WC3, and Dota which inherited it, is widely documented to use a "Pseudo Random Distribution" for proc-style chances (critical strike, evasion, bash) rather than an independent Bernoulli trial: the probability of the event on the N-th attempt since the last success is `P(N) = C * N`, with `C` strictly below the advertised probability and the counter resetting on success. **community-consensus on existence**, <https://github.com/supawesome/PRD>.

The constants are a different matter. The C table in that repository is computed from the model by simulation, not read out of the game: it is the community's model of PRD, calibrated so the long-run rate matches the listed probability. Whether WC3 1.29's tables hold those exact constants, and which abilities use PRD versus a plain uniform roll, is contested (there are threads specifically arguing about evasion). **unverified on constants and on coverage.** Liquipedia's PRD article, the usual reference, is CAPTCHA-blocked and could not be read: <https://liquipedia.net/warcraft/Pseudo_Random_Distribution>.

PRD is a per-source state machine layered on the global uniform stream. It changes how many draws are consumed per attack, and therefore the alignment of the entire downstream sequence. It must be modelled correctly or every subsequent random value diverges. Experiment O-9 measures it.

### 1.12 Where the seed comes from

The replay format stores a 32-bit `RandomSeed` in the game-start record, described as "the best bet on the random seed the Warcraft III engine is initialized with. The replay data that follows requires already a set up seed (since starting positions and race are fixed at this time)". For custom games on Battle.net or LAN "this dword appears to be the runtime of the Warcraft.exe of the game host in milliseconds"; for ladder games the value varies much more, so "probably the battle.net server hands out a 'real' seed". **documented** as to the field, **unverified** as to its origin. Section 4.12 of the w3g format specification v1.18, mirrored at <https://gist.github.com/bbcallen/d78c3fe03ede6f08914fde94815843ed>.

One 32-bit seed distributed once at game start, exactly the shape of `SetRandomSeed`. It belongs in the command stream at tick 0.

### 1.13 Turn structure and the per-turn checksum

The replay TimeSlot block (0x1F; 0x1E on patches up to 1.02) is a word byte-count, a word time increment in milliseconds ("about 250 ms on battle.net, about 100 ms on LAN and single player"), then CommandData blocks of `{1 byte PlayerID, 1 word action block length, n bytes of action blocks}`. **documented**, w3g spec v1.18 section 5.0, <https://gist.github.com/bbcallen/d78c3fe03ede6f08914fde94815843ed>, corroborated by the maintained parser <https://github.com/PBug90/w3gjs> (`src/parsers/GameDataParser.ts`). The same structure appears on the wire: `W3GS_INCOMING_ACTION` (0x0C) is `(UINT16) send interval`, `(UINT16) CRC-16`, then per action `(UINT8) player number`, `(UINT16) length`, `(VOID) action data`, per <https://bnetdocs.org/packet/440/w3gs-incoming-action> and <https://github.com/nielsAD/gowarcraft3> (`protocol/w3gs/packets.go`, type `TimeSlot`).

So the network turn is a command-batch turn at roughly 250 ms on Battle.net and 100 ms on LAN, not a simulation tick. The simulation tick rate is a separate, finer quantity that none of these sources pins down; see O-6.

Three independent sources agree that a small checksum travels with every turn, and none establishes what it covers. **community-consensus on existence, unverified on contents.** Replay block 0x22 always immediately follows a TimeSlot block and is `1 byte count (always 0x04 so far)` plus `1 dword (very random)`, with the spec authors noting "This message eventually syncs the random seed used for any calculation within the previous or next frame between all clients. It might be a complete gamescene checksum too though" (w3g spec v1.18). `W3GS_OUTGOING_KEEPALIVE` (0x27), client to host, carries one UINT32: "The unknown value may be a checksum and is also used in replays" (<https://bnetdocs.org/packet/464/w3gs-outgoing-keepalive>); gowarcraft3 names the type `TimeSlotAck` with `Unknown1 uint8` and `Checksum uint32`. An older protocol thread reaches the same unresolved state, <https://vl.bnetdocs.org/index.php?topic=17578.0>.

There is a tension worth chasing. The checksum is exchanged every turn, roughly every 250 ms, yet the community reports that "desyncs aren't detected instantly, some time may pass between the desync happening and game detecting it (approx. 0-15 seconds)" (<https://www.hiveworkshop.com/threads/explaining-warcrafts-lockstep-architecture-for-mapping-avoid-desyncs.351561/>). Either the checksum covers only a subset of state, or comparison is deferred or tolerant. Both readings have design consequences for our own state-hash design. Experiment O-7 attacks this black box.

### 1.14 No community-recorded desync cause is hardware or FPU related

The canonical community catalogue of desync causes lists, as certain causes: `GetLocalPlayer()` misuse, `SelectGroupForPlayerBJ`, `SmartCameraPanBJ` (fixed in 1.31), stale widgetizer caches, `GetCameraTargetPosition`, `BlzFrameSetText` inside local blocks, `GameCacheSync` flooding, `SetSkyModel` with a bad path, Lua `pairs()` iteration order, and certain Game Constants values. As probable causes: `GetLocationZ` during terrain deformation, weapon upgrade arithmetic where `Base + (Upgrade level - 1) * Increment` exceeds 14, bad models, memory leaks, zero-period timers, very short timers during map init, frame destruction, `ForGroup`/`ForForce` inside local blocks, and Lua GC affecting handle-id iteration order. As unverified: `GetLocationZ` differences between Classic/Reforged or Linux/Mac setups, background FPS caps with alt-tab, creating frames while tabbed out, and certain upgrade types. <https://www.hiveworkshop.com/threads/known-causes-of-desync.317486/>.

Every entry is an async-API misuse, an engine bug, or an iteration-order bug. **Nothing on the list is "different CPU", "different FPU", "AMD vs Intel", or "float rounding".** Across two decades of a modding community that hunts desyncs obsessively, the absence of a hardware-arithmetic entry is meaningful evidence that the 1.29-era engine's float arithmetic was stable across the machines its players actually used. **community-consensus, argument from absence.** It is not evidence about ARM or wasm, which no WC3 client ever targeted. The one arguable counterexample in the unverified bucket, `GetLocationZ` differences across setups, is a rendering-derived quantity and is consistent with 1.4 rather than against it.

The weapon-upgrade entry is worth flagging separately: an arithmetic threshold at 14 hints at an internal integer or table limit rather than float trouble. **unverified** mechanism.

### 1.15 The Legacy 1.29.2 client, and why its fidelity is not yet established

On 2026-04-29 Blizzard announced "Warcraft III - Legacy TFT 1.29" in the Battle.net App game-version dropdown for anyone who owns Warcraft III, and on 2026-05-08 shipped "Version 1.29.2 / Build 9232" with fixes for licence access, in-game cinematics, and locale installation. "The Legacy client supports offline and LAN play only." **documented**, <https://us.forums.blizzard.com/en/warcraft3/t/warcraft-iii-legacy-the-frozen-throne-129-now-available/38037>.

This is directly useful to WI-0017: the oracle client is an officially distributed 1.29.2 build, and LAN support means multi-client desync experiments are possible.

Two caveats, both **unverified**, both pointing the same way. First, one automated read of the companion community thread <https://us.forums.blizzard.com/en/warcraft3/t/warcraft-iii-legacy-tft-129-has-been-added-to-battlenet/38036> surfaced claims that this client's hitbox and pathing behavior, and its creep aggro, leash and target-priority behavior, differ from pre-1.30 originals. A second fetch of the same URL returned only truncated post bodies and the quotes could not be reproduced, so the claim is recorded without endorsement. Somebody should read that thread by hand. Second, **derived**: the Legacy client is labelled Build 9232, while the community patch history recorded in `docs/research/file-formats.md` pins the original 1.29.2 at build 9231. The one-build difference is unexplained here and is consistent with a rebuild rather than a byte-identical re-release. Both feed experiment O-10; if the deviations are real, the oracle must either be scoped to subsystems they do not touch or replaced with an untouched 1.29b build.

### 1.16 Comparative datapoint, not evidence about WC3

StarCraft: Brood War, the best-documented sibling engine, is described as using 24.8 fixed point in a plain `int32` for positions, velocities, angles and hit points, an LCG with the MSVC multiplier 22695477, and an FNV-1a hash of critical state broadcast every 32 frames for desync detection, with the diverged player dropped. <https://marianogappa.github.io/inside-brood-war/determinism.html>; the author states the analysis rests on OpenBW, not on disassembly. This tells us nothing directly about WC3, which demonstrably uses binary32 coordinates on the wire where Brood War does not. It establishes the design idiom Blizzard's RTS lineage came from and is a useful sanity reference for the shape of the checksum mechanism we are guessing at in 1.13.

## 2. What Odin gives us

Verdict up front, with the evidence level stated precisely: basic f32/f64 arithmetic (`+ - * /`) and `sqrt` are bit-reproducible today across every Odin target we care about, at every optimization level, with no flags needed. **Measured by execution on x86-64 only** (chain hashes across five optimization levels, plus a bit-identical V8 replica standing in for the wasm backend's semantics); for ARM64 and wasm the confirmation is at the object-code level (cross-compiled and disassembled: no fused multiply-add, no fast-math flags), not from running on those targets. The pinned toolchain never emits a fused multiply-add for source-level `a*b+c` on x86-64, ARM64 or wasm. Everything else is a hazard. Executing the probes on real ARM64 and a wasm runtime remains open (section 4).

### 2.0 Environment and reproduction

| item | value |
| --- | --- |
| CPU | Intel Core i5-4200U (Haswell); `sse2 fma sse4_1 sse4_2 avx f16c avx2` |
| OS / libc | Linux x86-64, Ubuntu 24.04, glibc `libm.so.6` |
| Odin | `toolchain/odin/odin version` reports `dev-2026-07-nightly:819fdc7` (upstream `819fdc7a80667498b8b365999f1475a66c358640`, 2026-07-10) |
| other tools | GNU ld 2.42, clang 20.1.2, `llvm-nm`/`llvm-objdump` from `/usr/lib/llvm-20/bin`, node v18.19.1 (V8) |
| not available | `wasm-ld`, a wasm runtime, 32-bit libc, ARM hardware. wasm and ARM results are from cross-compiled **object files** disassembled with `llvm-objdump`, not from execution. |

Probe sources were written to the git-ignored `tmp/wi0013_*`, so the durable record of each probe is the build command below plus the numbers in this section. Decision 0007 promotes the chain probe into a permanent golden-hash CI test, which is where these numbers acquire a long life.

```sh
# 1. chained arithmetic, all five optimization levels, with and without -microarch:native
for level in none minimal size speed aggressive; do
  ./toolchain/odin/odin build tmp/wi0013_chain.odin -file -o:$level -out:tmp/wi0013_chain_$level
done

# 2. FMA contraction and the fast_math attribute
./toolchain/odin/odin build tmp/wi0013_fma.odin -file -o:$level -out:tmp/wi0013_fma_$level
./toolchain/odin/odin build tmp/wi0013_fma.odin -file -o:$level -microarch:native -out:tmp/wi0013_fma_native_$level
./toolchain/odin/odin build tmp/wi0013_fastmath_bits.odin -file -o:speed -microarch:native -out:tmp/wi0013_fastmath_bits_native

# 3. transcendentals, three implementations over one input set
./toolchain/odin/odin build tmp/wi0013_odin_dump.odin -file -o:speed -out:tmp/wi0013_odin_dump
clang -O0 -o tmp/wi0013_libm_dump tmp/wi0013_libm_dump.c -lm
node tmp/wi0013_libm_dump.mjs

# 4. casts and edge cases
./toolchain/odin/odin build tmp/wi0013_casts.odin -file -o:$level -out:tmp/wi0013_casts_$level

# 5. cross-target codegen inspection (object files only)
./toolchain/odin/odin build tmp/wi0013_wasm_probe.odin -file -target:$t -build-mode:obj \
    -no-entry-point -o:speed -out:tmp/wi0013_$t   # t in freestanding_wasm32, wasi_wasm32, js_wasm32, linux_arm64, darwin_arm64
/usr/lib/llvm-20/bin/llvm-objdump -d --disassemble-symbols=probe_arithmetic,probe_fmuladd <obj>

# 6. LLVM IR inspection
./toolchain/odin/odin build tmp/wi0013_fma.odin -file -o:speed -build-mode:llvm-ir -out:tmp/wi0013_ir
```

### 2.1 Optimization level does not change basic arithmetic

The chain probe runs 200 000 rounds of a dependent f64 chain (multiply, add, subtract, divide, sqrt, sign flip), an identical f32 chain, and a 200 000-term dot-product reduction, all fed from an xorshift64* seeded from `os.args` so nothing folds at compile time, and prints an FNV-1a hash of every intermediate's bits.

Every build produced the identical hashes: `chain_f64` = `0x5cd8265d28d2090c`, `chain_f32` = `0xc829a02ef195d30c`, `dot_reduction` = `0x56e250c82e6696ca`. Final f64 accumulator bits `0x40733322d726ee9a`; dot-product sum bits `0x4171fd800ec7e5bc`. This held at `-o:none`, `-o:minimal`, `-o:size`, `-o:speed` and `-o:aggressive`, and again with `-microarch:native` appended. A line-by-line replica in JavaScript using `Number` (IEEE-754 binary64, the semantics wasm mandates for f64) run under node v18 produced the same `chain_f64` and `dot_reduction` hashes, which is independent evidence that nothing target-specific leaks into `+ - * / sqrt`.

Instruction mix changes with `-microarch` and the results do not: default builds emit SSE (`mulsd`, `movaps`, `movsd`), `-microarch:native` emits VEX-encoded equivalents (`vmulsd`, `vmovups`), still scalar, still one rounding per operation. No `-o` level auto-vectorised the dot-product reduction, which is expected, because reassociating a float reduction needs a fast-math flag that is never set. `-o:aggressive` is LLVM `-O3` and nothing more (`src/main.cpp:878-880`; the pass pipeline at `src/llvm_backend_passes.cpp` case 3 is the stock `default<O3>` minus coro, openmp and sroa).

### 2.2 FMA contraction: never, for source-level `a*b+c`

The FMA probe computes `a*b+c` three ways (naive, with the product forced through a volatile slot so it cannot fuse, and via `math.fmuladd`) on inputs chosen so a fused result differs from a split one: `c = -round(a*b)`, so a split evaluation is exactly 0 and a fused one is the rounding residue of the product.

With `a = 0x3ff123456789abcd`, `b = 0x400fedcba9876543`:

```
a*b+c        = 0x0000000000000000   (every level, every microarch)
math.fmuladd = 0x0000000000000000   (default microarch)
math.fmuladd = 0x3ca476595fab5e9c   (-microarch:native)
```

The f32 mirror, `a = 0x3f8abcde`, `b = 0x400fedcb`:

```
a*b+c        = 0x00000000
math.fmuladd = 0x00000000   (default microarch)
math.fmuladd = 0xb382d7d8   (-microarch:native)
```

The two `vfmadd213sd`/`vfmadd213ss` instructions in the `-microarch:native` binary are exactly the two `math.fmuladd` call sites; grepping the chain-probe binaries at `-o:aggressive -microarch:native` for `vfmadd|vfmsub` returns nothing.

Mechanism: `-build-mode:llvm-ir` on the FMA probe shows zero fast-math flags on any FP instruction across 34 000 lines of IR (`grep -cE "f(mul|add|sub|div) (fast|nnan|ninf|nsz|arcp|contract|afn|reassoc)"` returns 0). LLVM only contracts an `fmul`/`fadd` pair when both carry the `contract` flag, so Odin's default is effectively `-ffp-contract=off`. Clang's documented default is the opposite, `-ffp-contract=on`, fusing within a statement, for languages other than CUDA and HIP (<https://clang.llvm.org/docs/UsersManual.html#cmdoption-ffp-contract>). This is the single most important structural difference in our favour. The IR carries no `target-cpu` or `target-features` function attributes at all: `-microarch` is handed to the LLVM TargetMachine directly, which is why it can only affect instruction selection, including `llvm.fmuladd` lowering, and never IR-level algebra.

### 2.3 `@(fast_math=...)` exists, is opt-in, and is currently miswired

Odin has a per-procedure `@(fast_math = {...})` attribute taking a bit_set of compiler-injected `intrinsics.Fast_Math_Flags` (`src/checker.cpp:4269-4281`, flag ordinals at `src/types.cpp:811-831`, application at `src/llvm_backend_opt.cpp:61-73`). There is no command-line equivalent: no `-ffp-contract`, no `-ffast-math`, nothing FP-related anywhere in `odin build --help`.

`src/llvm_backend_opt.cpp:63-69` masks the bit_set value against each flag's **ordinal** instead of `1 << ordinal`, so `fast_math_flags & OdinFastMath_Allow_Contract` tests against the value 5. Measured consequence (`-o:speed -microarch:native`, one exported procedure per flag, called through a volatile function pointer so nothing inlines):

| attribute | bit_set value | `& 5` | contracted? | `vfmadd` emitted? |
| --- | --- | --- | --- | --- |
| *(none)* | 0 | 0 | no | no |
| `{.Allow_Reassoc}` | 1 | 1 | **yes** | **yes** |
| `{.No_NaNs}` | 2 | 0 | no | no |
| `{.No_Infs}` | 4 | 4 | **yes** | **yes** |
| `{.No_Signed_Zeros}` | 8 | 0 | no | no |
| `{.Allow_Reciprocal}` | 16 | 0 | no | no |
| `{.Allow_Contract}` | 32 | 0 | **no** | no |
| `{.Approx_Func}` | 64 | 0 | no | no |

Asking for contraction does not get it, and asking for reassociation or no-infinities silently does. Reported upstream as [odin-lang/Odin#7068](https://github.com/odin-lang/Odin/pull/7068), open since 2026-07-16, which additionally notes that fixing the mask unmasks a second problem: `Allow_Reassoc` aliases the `nneg` flag on `uitofp`, turning unsigned conversions signed. Still unfixed on master `9932b4d2d4bd` as of 2026-08-11, verified by re-reading the file from the master ref. The practical effect today is that fast-math is harder to enable by accident than it looks, but the flag names in source do not mean what they say, which is why decision 0007 bans the attribute in sim code outright rather than relying on the current miswiring.

### 2.4 Transcendentals: what routes where

Read from the toolchain source, then confirmed against the emitted binaries.

| function | native (`#+build !js`) | js_wasm32 (`#+build js`) | deterministic? |
| --- | --- | --- | --- |
| `sqrt` | `intrinsics.sqrt`, so `sqrtsd`/`sqrtss` on x86, `fsqrt` on ARM, `f64.sqrt` on wasm | `intrinsics.sqrt` | **yes**, IEEE-754 correctly rounded everywhere |
| `sin`, `cos` | `llvm.sin.*`/`llvm.cos.*`, so libm `sin`/`cos`/`sinf`/`cosf` | `odin_env.sin`/`cos`, so JS `Math.sin`/`Math.cos` | **no** |
| `exp` | `llvm.exp.*`, so libm `exp`/`expf` | `odin_env.exp`, so JS `Math.exp` | **no** |
| `pow` | `llvm.pow.*`, so libm `pow`/`powf` | `odin_env.pow`, so JS `Math.pow` | **no** |
| `fmuladd` | `llvm.fmuladd.*`: `vfmadd`, `fmadd`, or split, per target and microarch | `odin_env.fmuladd` = `(x,y,z) => x*y + z` | **no** |
| `ln` | **Odin source**, a FreeBSD msun `e_log.c` port | `odin_env.ln`, so JS `Math.log` | native yes, but native and js disagree |
| `log`, `log2`, `log10` | built on `ln` | built on the js `ln` | same as `ln` |
| `tan` | `sin(x)/cos(x)` | same | inherits the `sin`/`cos` hazard |
| `asin`, `acos`, `atan`, `atan2` | **Odin source**, msun ports | same Odin source | **yes**, depends only on `+ - * / sqrt` |
| `floor`, `ceil`, `trunc`, `round`, `mod`, `modf` | **Odin source**, bit manipulation | same | **yes** |
| `cbrt`, `erf`, `gamma`, `lgamma`, `log1p` | **Odin source** | same | **yes** |

Source: `toolchain/odin/core/math/math_basic.odin:7-40` (the `llvm.*` foreign block), `:112-120` (`sqrt`), `:126` (`ln_f64`, the msun port); `core/math/math_basic_js.odin` (the whole js variant); `core/math/math.odin:377` (`tan = sin/cos`); `core/sys/wasm/js/odin.js:1604-1611` (the JS shim). Confirmed on the binaries: `nm -D --undefined-only` on the transcendental probe lists `cos`, `cosf`, `exp`, `expf`, `pow`, `powf`, `sin`, `sinf` against glibc, `ldd` shows `libm.so.6`, and there is no `log`/`ln` import anywhere, matching "`ln` is Odin's own code".

**How far apart two real libm implementations are.** Three programs (glibc via clang, V8 via node, and `core:math` via Odin) evaluated one identical 20 000-sample input set. The inputs themselves came out bit-identical from all three, another confirmation of 2.1. Differing results:

| comparison | sin | cos | ln / log | exp | pow |
| --- | --- | --- | --- | --- | --- |
| Odin native vs glibc | 0 | 0 | **662 (3.31 %)** | 0 | 0 |
| Odin native vs V8 | 644 (3.22 %) | 651 (3.26 %) | 84 (0.42 %) | 1999 (9.99 %) | 1932 (9.66 %) |
| glibc vs V8 | 644 (3.22 %) | 651 (3.26 %) | 642 (3.21 %) | 1999 (9.99 %) | 1932 (9.66 %) |

Every mismatch is exactly 1 ULP; the maximum ULP gap across all five functions and all mismatches is 1. Examples:

```
sin  x = 0x401e66f9901b20ae   odin/glibc 0x3feefa5a2a4b57f7   V8 0x3feefa5a2a4b57f8
exp  x = 0xc01cf2d1a5116b57   odin/glibc 0x3f47928dedca220d   V8 0x3f47928dedca220c
ln   x = 0x40278dead2c10ed3   odin       0x4003bab429bd569e   glibc log 0x4003bab429bd569d
```

Two readings of one table. `sin`, `cos`, `exp` and `pow` matching glibc exactly while `ln` does not is a clean proof that the routing table above is right. And "roughly 3 % of `sin` results and 10 % of `exp` results differ by 1 ULP between two mainstream implementations" is the concrete price of putting a libm call inside a lockstep simulation. One ULP is one desync. `math.ln` deserves its own note: it is Odin code on native and `Math.log` on `js_wasm32`, so the same Odin source computes a different `ln` on the two targets, on 0.42 % of samples, with no compiler warning.

**Two further native-versus-js divergences inside `core:math` itself**, read from `core/math/math_basic_js.odin` and present identically in the pinned toolchain and on current master:

- Every f32 transcendental on js targets is computed at f64 and narrowed: `sin_f32`, `cos_f32`, `exp_f32`, `pow_f32`, `ln_f32`, `sqrt_f32` are all `f32(<f64 version>(f64(x)))` (lines 34-41), while native builds call the f32 libm entry points directly. Even with an identical underlying algorithm, computing in f64 and narrowing double-rounds and will not match computing in f32. This is a systematic, algorithm-independent divergence for every f32 transcendental between native and `js_wasm32`, and it means that even a hypothetical world where all libms agreed would still leave the two targets apart on f32.
- `fmuladd_f32` and `fmuladd_f16` on js compute `a*a + c`, not `a*b + c`: `math_basic_js.odin:33` and `:41` pass `f64(a)` twice, silently discarding `b`. A plain wrong-argument bug in the core library, still present on master.

**glibc's own versioning turned out not to bite.** This machine's `libm.so.6` ships two generations of several functions at distinct addresses under different symbol versions (`exp`/`pow`/`log` at both `GLIBC_2.2.5` and `GLIBC_2.29`, `expf`/`powf`/`logf` at both `GLIBC_2.2.5` and `GLIBC_2.27`). A probe binding to both via `.symver`, verified distinct by two PLT slots per function, compared 200 000 samples and found 0 differing results for `exp`, `log`, `pow`, `expf`, `powf`, and 0 between `sincos` and separate `sin`/`cos`. Honest negative result: the libm hazard is about *different libms* (glibc vs musl vs Apple Libsystem vs the MSVC CRT vs wasi-libc vs a JS engine), not about glibc versions. The `sincos` control still matters, because the optimizer changes which entry point gets called: `-o:none` imports `sin sinf cos cosf` while `-o:speed` imports `sin cos sincos sincosf`, LLVM having merged the `sin(x)/cos(x)` pair inside `math.tan` into a `sincos` call. Output was unaffected here, but this is exactly the shape of an optimization-level-dependent libm routing change, and it is not something we control.

**Compile-time constants are folded on the build host.** `math.sin(f64(1.0))` and friends with constant arguments are folded by LLVM at compile time, and cross-compiling to `linux_arm64` and `linux_amd64` bakes in identical constants: `folded_sin` = `0x3FEAED548F090CEE`, `folded_exp` = `0x4005BF0A8B145769`, `folded_pow` = `0x400142E81C889914` on both targets, all three matching this machine's runtime glibc exactly. The mechanism is `ConstantFoldFP(double (*NativeFP)(double), ...)` in `llvm/lib/Analysis/ConstantFolding.cpp`, which calls the host math library, with the comment "Currently APFloat versions of these functions do not exist, so we use the host native double versions", two `FIXME: Stop using the host math library` markers, and a hidden `-disable-fp-call-folding` escape hatch we cannot reach from Odin. Practical consequence: `math.sin(CONSTANT)` gives the build machine's answer and `math.sin(runtime_value)` gives the run machine's, so two builds of the same source on two different build hosts can differ.

### 2.5 Casts, rounding and edge cases

All of the following are as IEEE-754 requires and stable, identical at `-o:none` and `-o:speed`. f64 to f32 narrowing is round-to-nearest-even (`0x3ff0000010000000`, an exact tie on the even side, gives `0x3f800000`; `0x3ff0000030000000`, a tie on the odd side, gives `0x3f800002`). f32 subnormal results are produced, not flushed (`0x3690000000000001` gives `0x00000001`). There is no FTZ or DAZ anywhere: an f64 subnormal survives `* 1.0` and `+ 0.0` unchanged, min-normal times 0.5 gives `0x0008000000000000`, and the Odin runtime never touches MXCSR or FPCR (a grep for `mxcsr|fesetround|_controlfp|fpcr` over `base/` and `core/` finds only `core/sys/linux` struct fields and the unused `core/simd/x86` `ldmxcsr`/`stmxcsr` bindings). i64 to f64 is round-to-nearest-even (`2^53+1` gives `2^53`, `2^53+3` gives `2^53+4`). Signed zero is preserved through `*` and `/`, and `0.0 + -0.0` gives `+0.0`, per IEEE. `math.round` is half-away-from-zero (2.5 gives 3, -2.5 gives -3), Odin source, deterministic, as are `floor`, `ceil` and `trunc`. `f16` works: `f16(1/3)` gives `0x3555`.

Three watch items. NaN bit patterns are platform-specific: x86 produces the negative default NaN (`0/0`, `inf-inf` and `sqrt(-1)` all give `0xfff8000000000000`), ARM's default NaN is the positive `0x7ff8000000000000`, and wasm leaves the payload nondeterministic (2.7). NaN payloads do propagate through arithmetic on x86 (`0x7ff8000012345678 * 1.0` is unchanged), but f64 to f32 narrowing canonicalises them to `0x7fc00000` and drops the payload. Never hash raw NaN bits, and never let a NaN into sim state. Separately, `max(-0.0, 0.0)` returns `-0.0` (`0x8000000000000000`), as does `min(-0.0, 0.0)`: the builtins keep the first argument on a tie rather than following IEEE `maxNum`, which is deterministic within a target but lowers to different instruction families on x86 and ARM and has not been checked on ARM. Finally, Odin has no C99 hex-float literals: `0x1p-52` is a syntax error and the spelling is `0h3ff0000000000001`, a raw bit pattern, which is handy for writing exact test vectors.

### 2.6 Float to integer conversion is the sharpest hazard found

Three separate defects stack here, and together they are why decision 0007 routes every float-to-int conversion in sim code through checked `simmath` helpers.

**(a) Out-of-range conversion is LLVM poison, and is unstable run to run on one machine.** LLVM defines `fptosi`/`fptoui` as returning poison when the value is not representable, and Odin emits them unguarded. Reproducing the upstream reproducer from [odin-lang/Odin#7248](https://github.com/odin-lang/Odin/issues/7248) on the pinned toolchain (`a: f64 = 1e30; fmt.printf("%d 0x%08x\n", i32(a), u32(i32(a)))`, four consecutive runs of each binary):

| build | run 1 | run 2 | run 3 | run 4 |
| --- | --- | --- | --- | --- |
| `-o:none` | `0 0x00000000` | `0 0x00000000` | `0 0x00000000` | `0 0x00000000` |
| `-o:minimal` | `23058 0x5f004e28` | `25841 0xe7d4fe28` | `22320 0x25b93e28` | `24888 0xd7f08e28` |
| `-o:speed` | `0 0x00000000` | `0 0x00000000` | `0 0x00000000` | `0 0x00000000` |
| `-o:aggressive` | `30754 0x00000000` | `31332 0x00000000` | `31570 0x00000000` | `32488 0x00000000` |

Same binary, different answer every run, and the two renderings of the same expression disagree with each other. Our optimization levels misbehave differently from the ones in the upstream report, which is what poison does. The issue is open, filed 2026-08-07.

**(b) Even when the value is opaque and the poison collapses, the answer is target-specific.** Measured on x86-64 with values forced through volatile slots, against the instruction selected on each target:

| expression | x86-64 | ARM64 | wasm |
| --- | --- | --- | --- |
| instruction for `i32(f64)` | `cvttsd2si %xmm0,%rax` then low 32 bits | `fcvtzs x0, d0` then low 32 bits | `i64.trunc_sat_f64_s` + `i32.wrap_i64` |
| `i32(1e300)` | **0** (measured) | -1 | -1 |
| instruction for `i32(f32)` | `cvttss2si %eax` | `fcvtzs w0, s0` | `i32.trunc_sat_f32_s` |
| `i32(f32(3e9))` | **-2147483648** (measured) | +2147483647 | +2147483647 |
| `i64(1e300)` | **-9223372036854775808** (measured) | +9223372036854775807 | +9223372036854775807 |

x86 gives the integer-indefinite value, ARM and wasm saturate: opposite ends of the range.

**(c) `i64(f32)` and `u64(f32)` truncate through a 32-bit intermediate on every target.** This one is a plain correctness bug, not only a determinism one. `f32 3e+09` gives `i64 -2147483648` where 3000000000 is expected, `f32 -3e+09` gives `-2147483648`, and `f32 1e+18` gives `-2147483648`, identically at `-o:none` and `-o:speed`. Disassembly of `proc "c" (x: f32) -> i64 { return i64(x) }` shows `cvttss2si %xmm0, %eax` then `cltq` on linux_amd64, `fcvtzs w8, s0` then `sxtw x0, w8` on linux_arm64, and `i32.trunc_sat_f32_s` then `i64.extend_i32_s` on wasi_wasm32: a 32-bit destination followed by a widen, on all three. `u64(f32)` is equally broken (`cvttss2si %rax` then `movl %eax,%eax`). The workaround `i64(f64(x))` emits the correct `cvttss2si %xmm0, %rax` / `fcvtzs x0, s0`. A best-effort search of the Odin issue tracker turned up nothing; it looks unreported.

### 2.7 wasm, ARM64, and the other targets

**wasm, object-level, not executed.** Undefined symbols from the probe built with `-build-mode:obj`: `freestanding_wasm32` and `wasi_wasm32` both import `sin`, `cos`, `exp`, `pow` (plus `__stack_pointer` and `__indirect_function_table`), while `js_wasm32` imports `odin_env..sin`, `..cos`, `..exp`, `..pow`, `..ln`, `..fmuladd`. So the wasi and freestanding targets need some wasm libm to supply the transcendentals, whichever one the eventual `wasm-ld` link pulls in, typically wasi-libc's musl-derived routines, while `js_wasm32` hands them to the host JavaScript engine whose `Math.*` results are the ones measured above as diverging from glibc on 3 % to 10 % of inputs. Disassembly of `wasi_wasm32` at `-o:speed`: `probe_arithmetic` is `f64.mul f64.add f64.div f64.sub f64.abs f64.sqrt`, `probe_fmuladd` is `f64.mul f64.add` (so `llvm.fmuladd` expands rather than fusing), `probe_sin` is a `call` to the imported `sin`.

The WebAssembly core spec backs this up. Execution/Numerics states that "All operators use round-to-nearest ties-to-even, except where otherwise specified", and under NaN Propagation that if every NaN input is canonical, including the no-NaN case, the output payload is canonical too, otherwise "the payload is picked non-deterministically among all arithmetic NaNs; that is, its most significant bit is 1 and all others are unspecified", with the exception that "in the deterministic profile ... a positive canonical NaN is reliably produced". <https://webassembly.github.io/spec/core/exec/numerics.html>. So non-NaN f32/f64 `add/sub/mul/div/sqrt/min/max/floor/ceil/trunc/nearest` are bit-exact against native IEEE hardware, NaN bits are not portable, and wasm has no scalar FMA instruction at all: the f-unop set is `abs | neg | sqrt | ceil | floor | trunc | nearest` and the f-binop set is `add | sub | mul | div | min | max | copysign` (<https://webassembly.github.io/spec/core/syntax/instructions.html#numeric-instructions>). The only fused forms are `relaxed_madd`/`relaxed_nmadd` in relaxed-SIMD, which are nondeterministic by design and must never be enabled.

**ARM64, object-level, not executed.** `linux_arm64` and `darwin_arm64` are byte-identical in the interesting places: `probe_arithmetic` is `fdiv d3,d0,d1 ; fmul d0,d0,d1 ; fadd d0,d0,d2 ; fabd d0,d0,d3 ; fsqrt d0,d0`, `probe_fmuladd` is `fmadd d0,d0,d1,d2`, `probe_f32_arith` is `fmul s0,s0,s1 ; fadd s0,s0,s2`, `probe_sqrt32` is `fsqrt s0,s0`, and the undefined symbols are `sin cos exp pow` (`_sin _cos _exp _pow` on darwin, so Libsystem).

`a*b+c` is `fmul` plus `fadd` on ARM64, not `fmadd`. This is the headline ARM result and it removes the risk this slice was chartered to investigate: the "ARM fuses by default" folklore is a C/C++ property coming from Clang's `-ffp-contract=on` default, not an ARM one, and Odin's IR carries no `contract` flag for the ARM backend to fuse with. The `fabd` (floating absolute difference) emitted for `abs(x-y)` looks fused but is IEEE-exact, since `fsub` is correctly rounded and `fabs` is exact. `math.fmuladd` therefore produces three different answers across our targets from one source line: fused on ARM64 and on x86-64 built with an FMA-capable `-microarch`, split on baseline x86-64 and on wasm. The remaining ARM risk is entirely in the libm column: Apple's Libsystem `sin/cos/exp/pow` are a different implementation from glibc's and will diverge at the ULP level exactly as V8 does. Untested here for lack of hardware.

**Other targets, for the record.** `windows_amd64` is SSE2, `mulsd` plus `addsd` for `a*b+c`, `math.fmuladd` split at baseline microarch, the same as `linux_amd64`; the Windows CRT's transcendentals are a third implementation. `linux_i386` is **x87**: `probe_arithmetic` compiles to `fldl / fmul / faddl / fdivp / fsubp / fabs / fsqrt`, so 80-bit extended intermediates with only the final store rounding to f64. That is a hard determinism break against every 64-bit target, and, not coincidentally, it is how the original 32-bit WC3 binary computed (1.6). Exclude i386 from our sim targets, and note it as a lever if we ever want to reproduce x87 behavior rather than avoid it.

### 2.8 This is an implementation property, not a language guarantee

The Odin overview documents that "Floating-point values are comparable and ordered, defined by the IEEE-754 standard" and, crucially, that "An implementation may combine multiple floating-point operations into a single fused operation, and produce a result that differs from the value obtained by executing and rounding the instructions individually" (<https://odin-lang.org/docs/overview/>). The language therefore permits contraction. Everything measured in 2.1 and 2.2 is a property of `dev-2026-07-nightly:819fdc7`, not a promise that survives a toolchain bump, and there is no command-line strict-FP switch to pin it with. This is the argument for decision 0007's golden-hash regression test: the chain probe of 2.1 becomes a permanent CI test so any toolchain change that alters float codegen fails loudly, and toolchain upgrades become deliberate events where the hash is re-blessed only with evidence.

### 2.9 What stays risky

- **Compiler upgrades**, per 2.8. The golden hash is the only defence.
- **ARM is inferred, not measured end to end.** The codegen evidence is solid and object-level, but nothing was executed. The first real ARM runner should run the chain probe and the casts probe before we call it settled.
- **wasm is inferred and not executed at all.** No `wasm-ld` and no wasm runtime on this machine. The `wasi_wasm32` object shows the right opcodes, but the link step pulls in a libm we have not inspected.
- **`min`/`max` on signed zeros** was measured on x86 only; ARM's `fmaxnm` family handles zeros differently from a compare-and-select and this has not been checked.
- **Layer-4 bit parity is not helped by any of this.** Everything in this part is about our determinism across our targets. Matching the original engine bit for bit would additionally require reproducing x87 80-bit intermediates and the 1.29b CRT's transcendentals, neither of which any of our targets does natively.

## 3. What open-realm teaches

corepunch/open-realm was read at commit `550973e5172e13f8d0178cbeb69611d5af68935c` (2026-08-10) in a clone of the official upstream <https://github.com/corepunch/open-realm>. Licence verified in the clone as MIT, `LICENSE` lines 1-3, "Copyright (c) 2024 corepunch". Reference only per project policy; nothing was copied. It is a Quake 2-shaped multi-game engine whose WC3 sim proper is roughly 18.5k lines of C, self-described as a "Playable prototype. Not parity yet." (`games/warcraft-3/readme.md:9-11`).

It made no determinism choices, because its architecture does not need them: the server simulates, clients receive delta-compressed entity snapshots and only interpolate. There is no lockstep, no state hashing, no replay, no client-side gameplay prediction, and no compiler or library work aimed at reproducible floating point. Greps for `lockstep`, `determinis*`, `desync`, `checksum`, `crc` and `state hash` over the whole tree hit only unrelated text.

**Weight assessment.** On numerics: low but not zero. The one datapoint worth keeping is that a working WC3-shaped sim with movement, pathing, combat, regeneration and fog of war was built entirely on 32-bit floats (`common/shared.h:231` `typedef float FLOAT;`, with `double` appearing nowhere in the WC3 sim), with integers for time, money and path costs, and none of the gameplay-visible mechanics needed more precision than that. That is mild evidence that f32 is dimensionally adequate for WC3 gameplay, which is a much weaker claim than "f32 is reproducible across our targets". On determinism: zero, since nothing there was tested for reproducibility. On RNG: zero, since there is no algorithm claim and no WC3 correspondence anywhere (`GetRandomInt` is `lowBound + rand() % (highBound - lowBound + 1)` at `games/warcraft-3/game/api/api_misc.h:967-972`). On architecture: moderate with a caveat, because their model tolerates non-determinism by construction while ours forbids it.

**Worth borrowing as shapes, not code.** Integer costs in the router with floats only at the boundary (`routeNode_t { int price; bool closed; }`, `common/routing.c:36-40`), which removes platform variance from the most branch-sensitive subsystem. Data tables instead of per-case branches for the attack-by-defense multiplier matrix (`games/warcraft-3/game/skills/s_attack.c:100-110`). Constants read from the game's own MiscData/MiscGame rather than hardcoded (`g_main.c:50-92`), which is a concrete inventory of the Misc fields a running sim needs and feeds WI-0015. Caching the flow field on the goal rather than the chaser (`g_monster.c:117-150`). A headless game-module test harness with a `before_each` world reset (`game/tests/t_utils.c:56-98`), roughly the shape WI-0014's harness needs. Pulling the tick clock through a single injected accessor, `gi.GetTime()`, which is why no sim code there reads a wall clock.

**Do not inherit, highlights.** `rand()` as the sim generator, with the same global stream shared with the particle renderer at render framerate (`skills/s_attack.c:76`, `api_misc.h:967-979`, `renderer/mdx/r_mdx_geoset.c:57-70`): implementation-defined across every platform we target, and in a lockstep design the shared stream alone would be fatal. Never seeding at all (`srand` appears once, only inside the `SetRandomSeed` native), where the seed is match input and belongs in the command stream at tick 0. Unconstrained libm in the per-tick hot path: `unit_moveindirection` and `unit_turn_toward` call `cosf`, `sinf` and `atan2f` per moving unit per tick (`g_ai.c:167-203`), which is the single most expensive lesson available from reading their code and directly motivates decision 0007's own-`simmath` rule. No FP control in the build at all (`Makefile:8` is `-Wall -Wmisleading-indentation -fno-common` plus include paths, with no `-O` level and no FP flags), so the absence of `-ffast-math` is luck rather than policy. Wall-clock-gated ticking with no catch-up (`server/sv_main.c:171-186`), where a tick skipped because the machine was busy is sim state that diverges. Untimestamped text commands applied immediately at packet-arrival time (`server/sv_user.c:175-199`, `g_commands.c:29-80`), which decision 0006 already forbids. Spatial-query order derived from link recency rather than entity id (`server/sv_world.c:84-118,128-159`), a deterministic function of movement history rather than of world state. Per-tick work budgets that change sim outcomes (`g_monster.c:112-146`, where the budget reset was commented out, so two flow-field bakes happen per process ever). Float health as authority with a lossy byte on the wire (`g_local.h:488-491`, `g_phys.c:130-131`), fine for a snapshot engine, wrong under lockstep where every client holds full state. Tolerance-only sim tests (`shared/test.h:70`, `T_FEQ` is `fabsf(a-b) <= eps`), which cannot catch the one-ULP divergence that ruins a match twenty minutes in. And 10 Hz as a number to copy (`common/shared.h:36` `#define FRAMETIME 100`), which is their engineering choice, unsourced against the real game, and interacts with the numeric decision because per-tick step size sets how much rounding error accumulates per game-second.

## 4. Open questions feeding WI-0017

Each item below is written as an experiment against a 1.29.2 client, since 1.10 shows patch-to-patch RNG drift is a live risk and 1.15 shows the available client's fidelity is itself unsettled.

**O-1. Reproduce the RNG black box.** Harvest `SetRandomSeed(s)` followed by a long `GetRandomInt(0, 2^31-1)` sequence for many seeds, dumped via `Preload` or a log to a file, then independently reconstruct a generator that matches. Start by confirming the published vectors: seed 12345 must yield 189832, 638801, 925099 for `GetRandomInt(0, 1000000)`, and seed 42 must yield 12 then 2 for `GetRandomInt(0, 18)`. Confirm or refute the 1.29-versus-1.31 divergence report (seed 10, `GetRandomInt(0, 100)`, 55 on 1.31 and something else on 1.29.2).

**O-2. Pin the integer range mapping.** Determine purely from observed outputs how a raw draw maps onto `[low, high]`: test tiny ranges (0..1, 0..2, 0..3) for bias, test the documented INT_MIN/INT_MAX degeneracy, and test reversed bounds. This is the part where the off-limits source's structural description must be re-derived independently or replaced.

**O-3. Pin the real mapping and its precision grid.** Sweep seeds for `GetRandomReal(0, 1)` and check whether every observed output is exactly `k * 2^-23` for integer k, which would confirm the mantissa-fill hypothesis of 1.8 without ever reading the decompiled description, and whether the maximum observed value is exactly `1 - 2^-23`. Then verify the `low + delta * (u - 1)` ordering by testing ranges where operation order is observable in the low bits, for example large `low` with small `delta`.

**O-4. Determine how many draws each sim event consumes, and in what order.** Set a fixed seed, perform one scripted attack, then read the next `GetRandomInt`: the offset reveals how many internal draws the attack consumed. Repeat for an N-dice attack, a proc-bearing attack (crit, evasion, bash), critter wander, and item drops. This is the highest-value experiment in the set, because draw count determines whether our sequence stays aligned with the real engine's at all.

**O-5. Is damage integer-rounded anywhere?** Give a unit a known non-integral effective damage (fractional armor via `BlzSetUnitArmor`, or a fractional damage factor), apply exactly one hit, and read `GetUnitState(u, UNIT_STATE_LIFE)` at full precision via `R2SW`. If life lands on a non-integer, damage is applied as a real; if it snaps, find the rounding mode. Repeat with a long chain of hits to see whether error accumulates or is re-quantized each hit.

**O-6. Simulation tick rate versus network turn.** The 250 ms and 100 ms figures of 1.13 are the command-batch interval, not the sim step. Measure the actual step with a periodic timer at ever-smaller periods, or a movement-distance-per-step measurement on a unit with known movement speed. Needed before any of our own timing decisions are fixed.

**O-7. What does the per-turn checksum cover?** With two LAN clients on the Legacy 1.29.2 build, capture 0x27 keepalives while deliberately perturbing exactly one piece of state at a time (a unit's position by an ULP-sized amount, a unit's hit points, a purely visual property) and observe which perturbations change the checksum and how quickly a drop occurs. This also resolves the 250 ms versus 0-15 s detection-latency tension in 1.13.

**O-8. Negative-armor exponential.** Measure damage taken at fractional negative armor values across a fine sweep and compare against `2 - 0.94^(-armor)` computed in binary32, in double, and via `exp2(log2(0.94) * -armor)`. The residual pattern reveals whether the engine evaluates a true `pow`, an `exp`/`log` pair, a repeated multiply over integer armor, or a table. Determines whether bit-exact `pow` is needed for parity, and gives `simmath`'s implementation its acceptance target.

**O-9. Does PRD exist in 1.29b, on which abilities, and with which constants?** Fixed seed, thousands of scripted attacks with a known crit or evasion chance, recording the gap distribution between successes. A geometric distribution means plain Bernoulli; a triangular-ish distribution with a hard cap means PRD, and the gap histogram yields C directly. Repeat per ability (critical strike, evasion, bash, item procs), because the community disagrees about which use it.

**O-10. Is the Legacy 1.29.2 client a faithful 1.29b oracle?** Read <https://us.forums.blizzard.com/en/warcraft3/t/warcraft-iii-legacy-tft-129-has-been-added-to-battlenet/38036> by hand and check the reported hitbox, pathing and creep-behavior deviations of 1.15, and account for the build 9232 versus 9231 discrepancy. If the deviations are real, either find an untouched 1.29b build or scope the oracle to subsystems they do not touch.

### Questions this research could not settle at all

- **Could Mac and Windows clients ever share a Battle.net or LAN game?** Repeated searches found no authoritative statement. If yes, the 2002 engine achieved bit-identical arithmetic across PowerPC and x87, which would be the single most useful fact available about how disciplined the original sim's float usage was. Worth one focused pass through the printed manual, 2002-era press material, or Blizzard support archives.
- **Whether the 1.29-era Windows build emits x87 or SSE2.** Only answerable by disassembly, which is off-limits. Sidestep it by measuring behavior rather than instructions.
- **What state the desync checksum hashes.** Nobody in the accessible literature knows. O-7 is a partial black-box attack on it, and until it lands, our own state-hash design has no reference to copy.
- **The published `GetRandomReal` test vectors: resolved.** The grounding review's re-read of the upstream README (2026-08-11) established the six reals are consecutive draws (see 1.9); they are usable as oracle vectors. What remains open is only their confirmation against a live 1.29.2 client alongside the integer vectors (O-2).
- **The map checksum algorithm** used in the replay's map record; the w3g format spec marks it TODO. Relevant to the replay work item rather than to numerics.
- **ARM and wasm runtime behavior**, per 2.9: both are inferred from object code, and neither has been executed.

## Sources

Official Blizzard:

- <http://classic.battle.net/war3/basics/armorandweapontypes.shtml>. Armor formulas, including `2 - 0.94^(-armor)`.
- <http://classic.battle.net/war3/faq/features.shtml>. Minimum specs (Pentium II 400 MHz, G3 400 MHz), "a variation of the peer-to-peer model", replays confirmed.
- <http://classic.battle.net/war3/faq/replays.shtml>. Replays store only user interface commands; not viewable across game versions.
- <http://classic.battle.net/war3/faq/general.shtml>. "We have no plans for versions on other operating systems."
- <http://classic.battle.net/war3/faq/multiplayer.shtml> and <http://classic.battle.net/war3/faq/bnetfaq.shtml>. Checked for cross-platform statements; none present.
- <https://us.forums.blizzard.com/en/warcraft3/t/warcraft-iii-legacy-the-frozen-throne-129-now-available/38037>. Legacy TFT 1.29 announcement (2026-04-29) and the 1.29.2 Build 9232 update (2026-05-08); offline and LAN only.
- <https://us.forums.blizzard.com/en/warcraft3/t/warcraft-iii-legacy-tft-129-has-been-added-to-battlenet/38036>. Companion community thread; source of the unverified fidelity concerns in 1.15 and O-10.

Format and protocol documentation:

- <https://alanfox2000software.github.io/war3-diy/doc/replay/files/w3g_actions.txt>. Action block documentation; coordinates as IEEE single precision.
- <https://gist.github.com/bbcallen/d78c3fe03ede6f08914fde94815843ed>. Mirror of "WarCraft III Replay file format description" v1.18 (2007-06-26, authors blue and nagger), including its explicit no-reverse-engineering disclaimer, TimeSlot block 0x1F, block 0x22, and section 4.12 RandomSeed. The original home <http://w3g.deepnode.de/> currently fails TLS certificate validation.
- <https://bnetdocs.org/packet/440/w3gs-incoming-action>. W3GS_INCOMING_ACTION (0x0C) layout, send interval and CRC-16.
- <https://bnetdocs.org/packet/464/w3gs-outgoing-keepalive>. W3GS_OUTGOING_KEEPALIVE (0x27); the UINT32 "may be a checksum and is also used in replays".
- <https://vl.bnetdocs.org/index.php?topic=17578.0>. Older protocol thread on W3GS 0x0C/0x26/0x27; documents the fields as unresolved.
- <https://github.com/nielsAD/gowarcraft3>. `protocol/w3gs/packets.go`: `TimeSlot` (0x0C) and `TimeSlotAck` (0x27) with a `Checksum uint32`.
- <https://github.com/PBug90/w3gjs>. `src/parsers/GameDataParser.ts`: maintained replay parser corroborating the TimeSlot/CommandData layout and the 0x22 block.
- <https://warcraft.wiki.gg/wiki/Warcraft_III/Patch_1.29.0>. 1.29.0 patch notes; Windows XP still supported, Mac 10.11+, no engine or architecture statements.
- <https://world-editor-tutorials.thehelper.net/pathmaps.php>. Pathing map resolution, 32 world units per cell.

Community API documentation and measurement:

- <https://github.com/lep/jassdoc> and <https://raw.githubusercontent.com/lep/jassdoc/master/common.j>. Randomization API contracts, async/desync annotations, the `BlzGetUnitZ` terrain-height sync note, the integer-versus-real field taxonomy, and the `GetLocalPlayer` lockstep statement.
- <https://github.com/lep/jassdoc/issues/151>, with comments <https://github.com/lep/jassdoc/issues/151#issuecomment-2143869913>, <https://github.com/lep/jassdoc/issues/151#issuecomment-2177178728>, <https://github.com/lep/jassdoc/issues/151#issuecomment-2177306404>. Reversed-bounds behavior derived from generated values, and the `GetRandomReal(0, 50)` measurement. Mixed provenance; see the off-limits register.
- <https://jass.sourceforge.net/doc/types.shtml>. JASS manual on primitive types; `real` assumed 32-bit IEEE 754, explicitly unverified by its own author.
- <https://www.hiveworkshop.com/threads/explaining-warcrafts-lockstep-architecture-for-mapping-avoid-desyncs.351561/>. Lockstep tutorial: full simulation on every client, minority-kick on divergence, 0-15 s detection latency, camera and unit Z not synced.
- <https://www.hiveworkshop.com/threads/known-causes-of-desync.317486/>. The community desync catalogue; no hardware or FPU entry anywhere in it.
- <https://www.hiveworkshop.com/threads/warcraft3-random-implementation.327901/>. Measured RNG divergence between a 1.29.2-era reimplementation and 1.31 in-game output.
- <https://github.com/huntergregal/PyJASSPrng>. README only; published in-game RNG test vectors and the note that the reimplementation is roughly 25 ULP off on reals.
- <https://github.com/supawesome/PRD>. Pseudo Random Distribution explanation and simulated C-constant table.
- <https://liquipedia.net/warcraft/Pseudo_Random_Distribution>. The usual PRD reference; CAPTCHA-blocked, not read.
- <https://github.com/inwc3/w3-bug-tracker>. Community WC3 bug tracker; searched, no desync, RNG or float issues among its 24 issues.
- <https://marianogappa.github.io/inside-brood-war/determinism.html>. StarCraft: Brood War determinism; comparative only.

Off-limits, recorded so they are not re-opened (see the register above for why):

- <https://www.hiveworkshop.com/threads/random.286109/>. Hex-Rays decompiler output.
- <https://bbs.kanxue.com/thread-110540.htm>. Reverse-engineering forum; not fetched.

Toolchain and specification sources for Part 2:

- Measured on the development machine, 2026-08-11. Probe sources were written to the git-ignored `tmp/wi0013_*`: `wi0013_chain.odin`, `wi0013_chain_js.mjs`, `wi0013_fma.odin`, `wi0013_fastmath_attr.odin`, `wi0013_fastmath_bits.odin`, `wi0013_transcendental.odin`, `wi0013_casts.odin`, `wi0013_f32conv.odin`, `wi0013_f32conv2.odin`, `wi0013_conv2.odin`, `wi0013_poison.odin`, `wi0013_wasm_probe.odin`, `wi0013_wasm_conv.odin`, `wi0013_fold.odin`, `wi0013_odin_dump.odin`, `wi0013_libm_dump.c`, `wi0013_libm_dump.mjs`, `wi0013_libm_versions.c`.
- Odin toolchain source read at `toolchain/odin/` (`dev-2026-07-nightly:819fdc7`): `core/math/math_basic.odin:7-40,112-120,126`; `core/math/math_basic_js.odin`; `core/math/math.odin:332-390` and `:1780-1900`; `core/sys/wasm/js/odin.js:1604-1611`.
- Odin compiler source at upstream `819fdc7a80667498b8b365999f1475a66c358640` and master `9932b4d2d4bd`: `src/llvm_backend_opt.cpp:61-73`; `src/types.cpp:811-831`; `src/checker.cpp:4269-4281`; `src/check_decl.cpp:1487`; `src/main.cpp:875-890`; `src/llvm_backend_passes.cpp` case 3.
- [odin-lang/Odin#7068, "Fixes fast_math attribute plumbing to llvm"](https://github.com/odin-lang/Odin/pull/7068), open since 2026-07-16.
- [odin-lang/Odin#7248, "Out-of-range float to int conversion emits LLVM poison; result is nondeterministic at `-o:speed`"](https://github.com/odin-lang/Odin/issues/7248), open since 2026-08-07.
- <https://odin-lang.org/docs/overview/>. IEEE-754 ordering, and the language's explicit permission to fuse.
- <https://webassembly.github.io/spec/core/exec/numerics.html>. Round-to-nearest ties-to-even; NaN propagation nondeterminism; the deterministic profile.
- <https://webassembly.github.io/spec/core/syntax/instructions.html#numeric-instructions>. f-unop and f-binop lists; no scalar FMA; `trunc` versus `trunc_sat`.
- <https://clang.llvm.org/docs/UsersManual.html#cmdoption-ffp-contract>. Default `on` for languages other than CUDA and HIP.
- <https://github.com/llvm/llvm-project/blob/main/llvm/lib/Analysis/ConstantFolding.cpp>. `ConstantFoldFP` calling the host libm; `-disable-fp-call-folding`; the two "FIXME: Stop using the host math library" markers.

Reference codebase for Part 3:

- <https://github.com/corepunch/open-realm> at commit `550973e5172e13f8d0178cbeb69611d5af68935c`, licence verified MIT in the clone. All Part 3 claims are `path:line` citations into that commit. No behavioral claim about the real Blizzard engine is taken from that codebase; where its comments assert one, that is recorded as their claim and is not adopted without independent confirmation under WI-0015 or WI-0017.

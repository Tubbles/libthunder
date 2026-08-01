# Odin ecosystem readiness for libthunder

Kickoff research assessing whether the Odin programming language ecosystem is ready to build libthunder, a clean-room Warcraft III engine reimplementation.
Primary target: Linux. Planned future ports: Windows, macOS, wasm/WebGPU.
Research date: 2026-08-01.
The local dev machine does not have Odin installed (`odin: command not found`).
Every claim below is followed by a source URL, or marked `[unverified]` when it could not be confirmed against a primary source.

## Release cadence, stability, and breaking-change track record

Odin has never reached a 1.0. Early tags ran `v0.0.3` (2016) through `v0.13.0` (Aug 2020), then switched to a monthly `dev-YYYY-MM` scheme starting `dev-2021-05`, with occasional same-month hotfix suffixes.
As of 2026-08-01 the latest release is `dev-2026-07a` (published 2026-07-10), and the repo has 100 tagged releases total (https://github.com/odin-lang/Odin/releases, queried via `gh api repos/odin-lang/Odin/releases`).
Cadence is roughly monthly; there are occasional gaps (no `dev-2025-05` tag exists between `dev-2025-04` and `dev-2025-06`).

There is no formal stability or semver policy.
The official FAQ states Odin "is not currently self hosted nor will be until *after* version 1.0 when the main implementation of the Odin compiler adheres to a specification and is heavily tested," and does not document any backward-compatibility guarantee (https://odin-lang.org/docs/faq/).

Breaking changes happen and are labeled as such in release notes.
Verified directly: the `dev-2026-03` release notes carry an explicit `## BREAKING Changes` heading, covering a full replacement of `core:os` with a rewritten API (previously `core:os/os2`), with the old implementation kept at `core:os/old` only "until sometime in Q3 of 2026," plus a breaking change to `core:sys/info`'s API shape (https://github.com/odin-lang/Odin/releases/tag/dev-2026-03, background article https://odin-lang.org/news/moving-towards-a-new-core-os/).
`dev-2026-06` release notes separately show "Removed Haiku from supported targets" and "Disallow `*` and `/` for `bit_set`s" as ordinary (unlabeled) entries in the same release (https://github.com/odin-lang/Odin/releases/tag/dev-2026-06).
Regressions within a single release also occur: `dev-2026-07a` was published five days after `dev-2026-07` specifically to fix `@(objc_implement)` being broken in that prior release (https://github.com/odin-lang/Odin/releases/tag/dev-2026-07a).

How real projects pin the compiler: `floooh/sokol-odin`'s CI workflow downloads an exact tagged release archive by URL rather than "latest," e.g. `https://github.com/odin-lang/Odin/releases/download/dev-2024-04/odin-ubuntu-amd64-dev-2024-04.zip` (https://github.com/floooh/sokol-odin/blob/main/.github/workflows/main.yml).
By contrast, Karl Zylinski's widely used game templates (`odin-raylib-hot-reload-game-template`, `odin-sokol-hot-reload-template`) do not pin a version in their README and just tell users to "have Odin installed" (https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template).
The de facto standard third-party GitHub Action for CI, `laytan/setup-odin`, supports pinning to either a specific tagged release or nightly (https://github.com/marketplace/actions/setup-odin); `laytan/odin-http`'s own CI pins to `release: nightly` (https://github.com/laytan/odin-http/blob/main/.github/workflows/ci.yml) while `karl-zylinski/odin-raylib-web`'s CI uses `release: false` for latest stable (https://github.com/karl-zylinski/odin-raylib-web/blob/main/.github/workflows/build.yml).

Given the pre-1.0, unlabeled-breaking-change reality confirmed above, libthunder should pin to an exact `dev-YYYY-MM[a]` tag from day one and upgrade deliberately, the same pattern `sokol-odin`'s CI uses.

## Installation on Linux

Three viable approaches, all confirmed:

1. **Official prebuilt release archives** (recommended). Every monthly tag ships a Linux amd64 and arm64 tarball, e.g. `odin-linux-amd64-dev-2026-07a.tar.gz` and `odin-linux-arm64-dev-2026-07a.tar.gz` (verified via `gh api repos/odin-lang/Odin/releases/tags/dev-2026-07a`, asset listing). Download the exact tag, unpack, and pin CI/README instructions to that tag. This is the simplest, matches how `sokol-odin`'s own CI pins itself (see above), and avoids the LLVM toolchain dependency below.
2. **Build from source.** `git clone https://github.com/odin-lang/Odin` then `make release-native` on Linux. Requires Clang/LLVM; the install docs state supported LLVM versions are currently "17, 18, 19, 20, 21, and 22" (https://odin-lang.org/docs/install/). Useful for tracking `master` between monthly tags or patching the compiler/vendor bindings, but adds a moving toolchain dependency.
3. **Distro packages.** Confirmed present and current via Repology (https://repology.org/project/odin-lang/versions): Arch Linux's official `extra` repo carries `odin` at `dev_2026_07` (https://archlinux.org/packages/extra/x86_64/odin/), plus AUR alternatives (`odin-git`, `aur.archlinux.org/packages/odin-git`); NixOS unstable tracks `dev-2026-07a` with stable channels pinned to older monthly tags; also present in Homebrew, Alpine Edge, Gentoo GURU. The official install docs explicitly disclaim these: "these packages are configured by third-parties and may be flawed, please direct support to their maintainers" (https://odin-lang.org/docs/install/).

Recommendation: pin the exact release-archive tag (option 1) in a `docs/toolchain.md`/CI file, and treat distro packages as convenient for local dev only, not as the canonical build input, since they are not officially supported per the install docs.

## Official vendor libraries relevant to a game engine

The full top-level `vendor/` directory on `odin-lang/Odin` master, confirmed by direct listing (`gh api repos/odin-lang/Odin/contents/vendor`, 2026-08-01): `ENet`, `OpenEXRCore`, `OpenGL`, `box2d`, `box3d`, `cgltf`, `commonmark`, `compress`, `curl`, `darwin` (Metal, MetalKit, CoreVideo, Foundation, QuartzCore), `directx` (d3d11, d3d12, d3d_common, d3d_compiler, dxc, dxgi), `egl`, `fontstash`, `ggpo`, `glfw`, `kb_text_shape`, `libc`, `libc-shim`, `lua`, `microui`, `miniaudio`, `nanovg`, `portmidi`, `raylib`, `sdl2`, `sdl3`, `stb`, `vulkan`, `wasm`, `wgpu`, `windows`, `x11`, `zlib`.

Everything in `vendor/` is repo-wide zlib-licensed (`gh api repos/odin-lang/Odin` license field: `Zlib`; https://github.com/odin-lang/Odin/blob/master/LICENSE), maintained by the official odin-lang core team, and released on the same monthly cadence as the compiler.
Directly relevant to a game engine and confirmed present: `OpenGL`, `vulkan`, `directx` (d3d11/d3d12), `darwin/Metal`, `wgpu` (see rendering section below), `sdl2`, `sdl3`, `glfw`, `x11/xlib` (windowing/input), `miniaudio` (audio), `stb`, `cgltf` (asset loading), `box2d`, `box3d` (physics), `zlib` and `core:compress` (pure-Odin gzip/zlib, separate from `vendor:zlib` which binds the system library), `ggpo` (rollback netcode, notable for an RTS).
`box2d`, `cgltf`, `stb`, and `miniaudio` were all last touched 2026-07-19 in a shell-script build-system rework (PR #7034), and `vulkan`/`directx`/`sdl3` were all touched within the last two months as of this writing, indicating active maintenance across the board.

There is no official official Odin `vendor:` binding for a standalone game-object/scene-graph or an ECS library, nor a first-party math/physics engine beyond Box2D/Box3D — expected, since `vendor/` is scoped to C library bindings rather than higher-level engine code.

## The wasm story

Odin's wasm targets, confirmed directly from compiler source (`src/build_settings.cpp`, https://github.com/odin-lang/Odin/blob/master/src/build_settings.cpp): `freestanding_wasm32`, `wasi_wasm32`, `js_wasm32`, `orca_wasm32`, `freestanding_wasm64p32`, `js_wasm64p32`, `wasi_wasm64p32`.
`wasm64p32` is "a pseudo-architecture which has 32-bit pointers but 64-bit int/uint... NOT THE SAME AS wasm64" per the FAQ (https://odin-lang.org/docs/faq/).
Emscripten is deliberately not supported in-tree; community discussion quotes the maintainers calling it "a set of bodges bodged together" as the reason (https://forum.odin-lang.org/t/so-many-different-wasm-build-targets/790).
`freestanding_wasm32` provides no default `context.allocator` — one must be supplied manually (same forum thread).

JS/DOM interop lives at `core/sys/wasm/js` (https://github.com/odin-lang/Odin/tree/master/core/sys/wasm/js): a thin, low-level FFI (`get_element_value_f64`, `set_element_style`, `alert`, `evaluate`, `set_document_title`, etc.), not a full DOM/wasm-bindgen-style binding.
A community project, `thetarnav/odin-wasm`, provides more ergonomic ES-module wrappers and WebGL bindings, but its own README describes part of it as "just an experiment" (https://github.com/thetarnav/odin-wasm).

**WebGPU in the browser is officially supported and more mature than expected.** The in-tree `vendor:wgpu` package explicitly targets both native desktop and the browser from the same source tree: `wgpu_native.odin` wraps the `gfx-rs/wgpu-native` C library for native targets, while `wgpu_js.odin` + `wgpu.js` wrap the browser's native WebGPU JS API directly for `-target:js_wasm32` and `-target:js_wasm64p32` (https://github.com/odin-lang/Odin/tree/master/vendor/wgpu, doc comment quoted below). Web builds require `-extra-linker-flags:"--export-table"` for the callback function table. This was added in 2024, credited primarily to contributor `@laytan` (https://github.com/odin-lang/Odin/discussions/3454, which also notes the WebGPU spec was "still rapidly evolving" at the time). An official example lives at https://github.com/odin-lang/examples/tree/master/wgpu/glfw-triangle with a `build_web.sh` script.

However, **no concrete shipped project using `vendor:wgpu` for browser WebGPU could be found**. Every actual browser-playable Odin game located uses the Raylib + Emscripten + WebGL path instead, not the native `js_wasm32` + `vendor:wgpu` path: the itch.io "odinlang" tag lists only three browser-playable entries (https://itch.io/games/tag-odinlang), and the clearest concrete example, Karl Zylinski's "The Legend of Tuna" (Odin + Raylib + Box2D, confirmed source at https://github.com/karl-zylinski/the-legend-of-tuna, language confirmed Odin via GitHub API), ships web builds through Emscripten per the companion template repo https://github.com/karl-zylinski/odin-raylib-web, not through `vendor:wgpu`. Treat browser-WebGPU-via-Odin as officially supported and documented, but essentially unproven in production.

Known gotchas reported by real Odin developers targeting wasm: `core:os` file functions are unimplemented on the JS target and crash at runtime if called; `core:math/rand`'s default 64-bit state can trigger a WASM unaligned-64-bit-access trap (both documented with fixes in a devlog: https://itch.io/devlog/1140864/web-build-crash-fixes-jswasm); binary size can balloon unexpectedly under `-debug` due to DWARF debug-info generation, one report going from 2,576 B to 126,874 B (https://forum.odin-lang.org/t/wasm-executable-size-jumps-unexpectedly/1202); wasm threading/atomics are opt-in via a target feature and effectively single-threaded by default (https://github.com/odin-lang/Odin/blob/master/base/runtime/wasm_allocator.odin).

## Rendering backend options

Four candidates were assessed against the portability matrix (Linux now, Windows/macOS/wasm later).

### (a) Raw OpenGL, `vendor:OpenGL`
- Status: official, in-tree, Glad-generated loader up to GL 4.6 core (https://github.com/odin-lang/Odin/tree/master/vendor/OpenGL).
- Linux: works, caller must supply a `GetProcAddress`-equivalent from GLFW/SDL/glX.
- wasm path: not directly usable; the separate official `vendor:wasm/WebGL` package (WebGL2, `js_wasm32`/`js_wasm64p32`) is the analogous web target, meaning desktop GL code must be ported rather than reused as-is (`gh api repos/odin-lang/Odin/contents/vendor/wasm`, listing includes `WebGL`).
- Maturity/maintainer: official odin-lang core team, actively touched (full rewrite Nov 2025).
- License: zlib (repo-wide).
- Tradeoff for libthunder: least risky short-term choice — every Odin desktop tutorial uses it — but it is a deliberate "use now, replace later" bridge, not a long-term wasm/WebGPU-compatible answer.

### (b) WebGPU via `vendor:wgpu` (wgpu-native)
- Status: official, in-tree (not third-party, contrary to the common assumption that WebGPU bindings would be community-maintained). Confirmed at https://github.com/odin-lang/Odin/tree/master/vendor/wgpu.
- Linux: code path exists (`ODIN_OS == .Linux` branch builds `lib/wgpu-linux-<arch>-<type>/lib/libwgpu_native<ext>`), but the repo only ships prebuilt Windows MSVC binaries in `vendor/wgpu/lib/`; Linux users must manually download the matching `wgpu-native` release binary from https://github.com/gfx-rs/wgpu-native/releases and place it under `vendor/wgpu/lib/wgpu-linux-<arch>-release/lib/` (documented in `vendor/wgpu/doc.odin`).
- wasm path: yes, documented and dual-targeted from the same source (see wasm section above) — this is the standout property of this backend versus the other three.
- Maturity: very active, most recent commit 2026-07-08 ("Update wgpu.js"); pinned to `wgpu-native v29.0.1.1`, confirmed as exactly `gfx-rs/wgpu-native`'s actual latest GitHub release, published 2026-06-23 (`gh api repos/gfx-rs/wgpu-native/releases/latest`). Commit history includes Odin's creator (`gingerBill`).
- Maintainer: official odin-lang core team.
- License: Odin-side zlib; upstream `wgpu-native` (gfx-rs project) is Apache-2.0 (`gh api repos/gfx-rs/wgpu-native` license field).
- Includes ready-made surface glue for SDL2, SDL3, and GLFW (`sdl2glue`, `sdl3glue`, `glfwglue` sub-packages), each with per-OS glue files.
- Tradeoff for libthunder: the only option that is both official and has a real, documented, dual native+web code path from the same abstraction. Its cost is that WebGPU is itself a comparatively young API with a "still rapidly evolving" spec history (per the Odin discussion thread cited above) and Linux native binaries require a manual download step not yet automated in the vendor package.

### (c) sokol_gfx via `sokol-odin`
- Status: **not** in `odin-lang/Odin` vendor/ (confirmed absent from the directory listing). Separate repo: https://github.com/floooh/sokol-odin, auto-generated bindings for https://github.com/floooh/sokol.
- Linux: README states "Supported platforms are: Windows, macOS, Linux (with X11)" explicitly — Wayland is not called out as supported. Requires `libglu1-mesa-dev, mesa-common-dev, xorg-dev, libasound-dev` and running `build_clibs_linux.sh` first. Default backend on Linux is GL (https://raw.githubusercontent.com/floooh/sokol-odin/main/README.md).
- wasm path: not documented in the top-level README's "Supported platforms" line, but the repo does contain `build_clibs_wasm.sh`/`.bat` and merged PRs adding WASM build scripts; the underlying C `sokol` library supports WASM via Emscripten with GLES3/WebGL2 and WebGPU backends. A community template, `karl-zylinski/odin-sokol-web`, demonstrated the workflow but is now archived in favor of `karl-zylinski/odin-sokol-hot-reload-template`, which also does web builds (verified via that repo's README: "This repository has been archived. However, the odin-sokol-hot-reload-template also does web builds.").
- Maturity: extremely active — last commit 2026-08-01 (today, per `gh api` commit query), 278 stars, CI badge present, not archived.
- Maintainer: `floooh` (Andre Weissflog, sokol's own upstream author) — an individual maintainer with direct authority over the underlying C library, not the odin-lang core team. Note `gingerBill/odin-sokol` also exists but is a much less recently touched alternative (last commit 2026-03-02) — treat `floooh/sokol-odin` as the maintained one.
- License: zlib, matching upstream sokol's zlib license.
- Tradeoff for libthunder: strongest backend-abstraction story (same C library targets GL/D3D11/Metal/WebGPU-via-Emscripten depending on platform, so libthunder's renderer code would not need per-platform branches at the sokol_gfx call-site level), maintained by the actual sokol author, and battle-tested outside the Odin ecosystem. Costs: not an official Odin package (dependency risk sits one layer further from the language maintainers), Linux is X11-only per its own README with no stated Wayland story, and the wasm path goes through Emscripten rather than Odin's native `js_wasm32` target.

### (d) SDL3 GPU API, `vendor:sdl3`
- Status: official, in-tree; `vendor/sdl3/sdl3_gpu.odin` provides full `GPUDevice`, `GPUBuffer`, `GPUShader`, render/compute/copy pass bindings (confirmed via file listing and content read).
- Linux: SDL3's GPU API backends are Vulkan (Windows/Linux/Switch/Android), D3D12 (Windows/Xbox), and Metal (macOS/iOS/tvOS) per SDL's own docs (https://wiki.libsdl.org/SDL3/CategoryGPU) — Linux is covered via the Vulkan backend. Odin's `vendor:sdl3` package is actively updated (commit 2026-07-25).
- wasm path: **not supported today.** SDL3's Emscripten wiki page does not mention the GPU API or WebGPU (https://wiki.libsdl.org/SDL3/README-emscripten). Upstream SDL has an open feature request, issue #10768 "SDL3 GPU Backend for WebGPU Target" (opened 2024-09-09, still open), and an unmerged experimental PR #16020 "GPU: Experimental WebGPU SDLGPU Backend" (opened 2026-07-18, still open as of 2026-07-31). Real work in progress, not shipped.
- Maturity/maintainer: official odin-lang core team for the bindings; SDL3 itself is licensed zlib.
- Tradeoff for libthunder: attractive because it collapses windowing and rendering into one dependency and gets Vulkan-quality performance on Linux today, but the wasm story is a known, currently-unresolved gap upstream in SDL itself — adopting it now means betting on SDL's own roadmap for the later web port.

### Summary table

| Backend | Official Odin binding | Linux today | wasm path | Maintainer |
|---|---|---|---|---|
| OpenGL | yes, `vendor:OpenGL` | yes | no (must switch to `vendor:wasm/WebGL`) | odin-lang core team |
| WebGPU / wgpu-native | yes, `vendor:wgpu` | yes (manual native lib download) | yes, documented, same source tree | odin-lang core team |
| sokol_gfx | no, `floooh/sokol-odin` | yes, X11 only | yes, via Emscripten (community template) | floooh (sokol author) |
| SDL3 GPU | yes, `vendor:sdl3` | yes, via Vulkan backend | no, upstream SDL WebGPU backend still unmerged | odin-lang core team |

## Windowing/input on Linux

All three common options exist as official vendor packages, plus low-level Xlib: `vendor:sdl2`, `vendor:sdl3`, `vendor:glfw`, `vendor:x11/xlib` (https://github.com/odin-lang/Odin/tree/master/vendor).

- `vendor:sdl2`: dynamically links `system:SDL2` on Linux; version constant documents SDL 2.0.16 as the baseline. Last vendor commit 2025-12-11.
- `vendor:sdl3`: same dynamic-link pattern; bound to SDL 3.4.2. Most actively maintained of the three, last commit 2026-07-25 with a run of "correct numerous issues, add missing procedures" commits through mid-2026.
- `vendor:glfw`: links against the **system's** installed glfw on Linux (no bundled `.so`), meaning Wayland support depends entirely on the distro's glfw build. GLFW's Wayland-native functions (added upstream in GLFW 3.4) are declared with weak linkage in the Odin bindings specifically so code can runtime-detect an old system glfw without a hard link failure — this was a deliberate fix, PR #3941 "improve WGPU / GLFW / Wayland story by weak linking and adjusting docs," merged 2024-07-18 (https://github.com/odin-lang/Odin/pull/3941, confirmed merged via `gh api`).

Wayland/X11 gotchas found in the wild: an Odin forum thread reports SDL3 windows staying blank unless `SDL_VIDEO_DRIVER=x11` is forced, tracing the root cause to Wayland requiring an explicit `RenderPresent()` buffer commit that X11 performs implicitly, so X11-authored tutorial code silently breaks under Wayland (https://forum.odin-lang.org/t/sdl3-on-linux-only-working-with-sdl-video-driver-x11/1377). A closed Odin GitHub issue shows a `vendor:wgpu` + SDL2 example panicking on Pop!_OS/X11 in 2024 ("sdl2 cannot recognize x11 platform," https://github.com/odin-lang/Odin/issues/4127). Upstream, SDL3 now defaults to native Wayland when the compositor supports the `fifo-v1` protocol and falls back to XWayland otherwise, an improvement over SDL2, which historically required opting in via `SDL_VIDEODRIVER=wayland` (https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_DRIVER, https://discourse.libsdl.org/t/is-wayland-really-default/61737). Upstream GLFW also has open Wayland-completeness friction unrelated to Odin, e.g. a clipboard crash on Hyprland (https://github.com/glfw/glfw/issues/2562).

Recommendation: **SDL3** is the vendor package with the most active 2026 maintenance, has the better native-Wayland default upstream, and (relevant to the wasm/WebGPU roadmap) `vendor:wgpu` ships ready-made glue for all three windowing libraries (`sdl2glue`, `sdl3glue`, `glfwglue`), so the windowing choice does not lock in the rendering choice. GLFW's dependency on whatever glfw the Linux distro happens to package (X11-only vs Wayland-capable) is a portability variable SDL3 avoids by bundling its own driver-selection logic.

## Audio

`vendor:miniaudio` bundles the miniaudio source directly (`vendor/miniaudio/src/miniaudio.h`, currently v0.11.24 per the embedded header, upstream-dated 2025-09-11); the header confirms upstream license as "public domain or MIT-0, your choice." Build scripts were reworked 2026-07-14/19 (https://github.com/odin-lang/Odin/tree/master/vendor/miniaudio).

Both `vendor:sdl2` and `vendor:sdl3` also expose low-level `SDL_audio` bindings plus a `mixer` sub-package (SDL2_mixer/SDL3_mixer wrapper). No definitive Odin-community consensus was found favoring one over the other; miniaudio's advantage is being single-header and dependency-free versus pulling in SDL's audio subsystem when SDL is already a dependency for windowing anyway (`[unverified]` beyond a general, non-Odin-specific indie-dev blog post listing both without a recommendation, https://www.indiegameprogramming.com/2026/02/19/why-choose-odin-lang.html). Since libthunder is already taking SDL3 for windowing, using `vendor:sdl3`'s audio subsystem avoids adding miniaudio as a second audio dependency; miniaudio remains the better choice if audio needs to be decoupled from the windowing library later (e.g. a headless server binary).

## Testing story

`core:testing` (https://github.com/odin-lang/Odin/tree/master/core/testing, docs at https://pkg.odin-lang.org/core/testing/) provides `@(test)`-attributed procs with signature `proc(t: ^testing.T)`, assertions (`expect`, `expectf`, `expect_value`, `expect_assert*`, `fail`, `fail_now`, `cleanup` for LIFO teardown, `expect_signal`, `expect_leaks`), and built-in memory-leak tracking.
`odin test <package>` compiles and runs all `@(test)` procs, multithreaded by default (one thread per test), configurable via `-define:` flags (`ODIN_TEST_THREADS`, `ODIN_TEST_RANDOM_SEED`, `ODIN_TEST_TRACK_MEMORY`, `ODIN_TEST_NAMES`, `ODIN_TEST_JSON_REPORT`, etc. — confirmed directly by reading `core/testing/doc.odin`); `-all-packages` tests a whole tree. Official doc: https://odin-lang.org/docs/testing/.

Fuzzing: **no built-in support.** Confirmed by grepping `core/testing` source for "fuzz" (zero matches) and checking the FAQ/testing docs (no mention). A web search for "odin lang fuzzing" surfaces only an unrelated PLDI 2022 academic paper coincidentally also named "Odin," with no connection to odin-lang.

Benchmarking: **not part of `core:testing`** either (zero matches for "benchmark" across `testing.odin`, `doc.odin`, `runner.odin`). It instead lives in `core:time`: `core/time/perf.odin` defines `Benchmark_Options` and a `benchmark()` proc using TSC-based timing (https://github.com/odin-lang/Odin/blob/master/core/time/perf.odin). In practice, community libraries roll their own ad hoc timing rather than using a formal harness — e.g. `laytan/odin-http` keeps informal micro-benchmarks in a `comparisons` directory (https://github.com/laytan/odin-http).

## Build tooling, vendoring, and CI conventions

Odin's unit of compilation is the package: every `.odin` file in a directory shares one `package` clause and compiles together. `odin build <dir>` builds a package; `-collection:<name>=<path>` maps a name to a directory tree so multi-package projects wire subfolders together via `import "name:sub/pkg"` (https://github.com/odin-lang/Odin/wiki/Compiler-Flags). There is no dedicated Odin build system beyond this — real projects layer shell scripts or Makefiles on top, e.g. `karl-zylinski/odin-raylib-web`'s `build_desktop.sh`/`build_web.sh` (https://github.com/karl-zylinski/odin-raylib-web), `FourteenBrush/odin-template`'s Makefile with `debug`/`release`/`test`/`check`/`run` targets (https://github.com/FourteenBrush/odin-template/blob/main/Makefile), and the Odin compiler's own repo, which uses a Makefile (`gmake release`).

There is no package manager, by explicit design. The FAQ states: "Odin will never officially support a package manager... Copying and vendoring each package manually, and fixing the specific versions down is the most practical approach" (https://odin-lang.org/docs/faq/). A community index of third-party libraries exists at https://github.com/odin-lang/Odin/wiki/Odin-Libs and https://github.com/jakubtomsu/awesome-odin. In practice, projects vendor via git submodules — `wrapperup/cool-engine-odin`'s `.gitmodules` pulls seven Odin binding repos into a `deps/` folder (repo confirmed to exist, https://github.com/wrapperup/cool-engine-odin) — or by direct clone of a single-package library like `laytan/odin-http` (confirmed to exist).

CI examples in the wild: `odin-lang/Odin`'s own CI builds the compiler from source and runs `./odin check` with `-vet -vet-tabs -strict-style -vet-style -warnings-as-errors` plus `./odin test ... -all-packages -define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true` (https://github.com/odin-lang/Odin/blob/master/.github/workflows/ci.yml). Downstream projects instead use the third-party `laytan/setup-odin` GitHub Action to install a compiler (release or nightly) rather than building from source — used by both `karl-zylinski/odin-raylib-web` and `laytan/odin-http` (URLs above).

## Notable shipped Odin games/engines

The official Odin showcase page (https://odin-lang.org/showcase/, fetched directly) lists, among non-game entries (Ols language server, Spall profiler, Todool):

- **Solar Storm** — a turn-based sci-fi destructible-terrain artillery game by Jakub Tomšů, built with Odin + sokol; described by the project's own devlog as the first game released on Steam written in Odin. https://odin-lang.org/showcase/solar_storm/, https://jakubtomsu.itch.io/solar-storm, devlog: https://jakubtomsu.github.io/posts/solar_storm_renderer/
- **CAT & ONION** — a short narrative cat-adventure game by Karl Zylinski, written in Odin + raylib. Confirmed shipped on Steam (Win/Mac/Linux/Steam Deck), released 2024-03-12, "99% positive" reviews at time of check. https://odin-lang.org/showcase/cat_and_onion/, https://store.steampowered.com/app/2781210/CAT__ONION/ (the Steam page itself, as expected of store marketing copy, does not name the tech stack — that claim rests on the official odin-lang.org showcase).
- **EmberGen** — a real-time volumetric VFX/fluid-simulation tool by JangaFX, described on the showcase page as written fully in Odin; a genuine production (non-game) commercial product, evidence Odin is used for demanding real-time graphics work beyond hobby projects. https://odin-lang.org/showcase/embergen/

One claim was checked and **rejected**: a sub-agent initially reported "Spanking Runners / Samogonki" (https://store.steampowered.com/app/2599800/Spanking_Runners/) as an Odin+sokol game, citing its listing on sokol's own showcase page. Direct inspection of its source repo (https://github.com/KD-lab-Open-Source/Samogonki) shows the primary language is **C++**, not Odin — the game uses the sokol C library directly, unrelated to `sokol-odin`. Excluded from this list; flagged here so the mistake isn't silently repeated in future research.

Smaller/game-jam-scale Odin projects exist (e.g. Karl Zylinski's "The Legend of Tuna," source confirmed at https://github.com/karl-zylinski/the-legend-of-tuna, language confirmed Odin) but nothing beyond the three entries above rises to verified, shipped-commercial-product status in this research pass. The Odin game-shipping ecosystem should be read as small and early, not mature.

## Recommended stack

**Windowing/input: SDL3** (`vendor:sdl3`). Most actively maintained of the official windowing bindings, better native-Wayland behavior than SDL2 upstream, and has ready-made `vendor:wgpu` glue (`sdl3glue`) for the wasm/WebGPU phase.

**Rendering: start on raw OpenGL (`vendor:OpenGL`) for the Linux-first milestone, with `vendor:wgpu` as the explicit target for the cross-platform/wasm rewrite.** OpenGL is the lowest-friction path to a first triangle on Linux today and is what most Odin tutorials/examples use, so early engine-architecture iteration won't be blocked on renderer plumbing. `vendor:wgpu` is the only backend among the four assessed that is both an official odin-lang package and has a real, documented, same-source-tree path to native desktop (via wgpu-native) and browser wasm (via the browser's own WebGPU API) — directly matching the stated Windows/macOS/wasm-WebGPU roadmap. Treat the OpenGL renderer as intentionally disposable: keep the engine's renderer interface backend-agnostic from the start so the OpenGL implementation can be swapped for a `vendor:wgpu` implementation without touching game logic. `sokol_gfx` was seriously considered (strongest backend-abstraction story, actively maintained by sokol's own author) but was set aside because it is not an official Odin package, its Linux support is explicitly X11-only per its own README, and its wasm path runs through Emscripten rather than Odin's native `js_wasm32` toolchain that the rest of the stack (and `vendor:wgpu`) already uses. SDL3 GPU was set aside for the wasm phase specifically because upstream SDL's own WebGPU GPU backend is still an unmerged, in-progress PR as of 2026-07-31 — adopting it now would tie libthunder's web port to SDL's roadmap rather than Odin's.

**Audio: `vendor:sdl3`'s SDL_audio subsystem** to start, since SDL3 is already a dependency for windowing and this avoids a second audio library. Revisit `vendor:miniaudio` if/when audio needs to run decoupled from the windowing library (e.g. a headless dedicated-server binary that has no SDL window).

**Toolchain: pin an exact `dev-YYYY-MM[a]` release tag** and install it from the official Linux release archive, matching the pattern `sokol-odin`'s own CI uses, rather than building from source or relying on distro packages (both viable but not the canonical source per Odin's own install docs).

What can be safely deferred:
- The final renderer backend choice for the wasm/Windows/macOS phase (`vendor:wgpu` vs. reconsidering `sokol_gfx`/SDL3 GPU once their gaps close) does not need to be locked in now — the OpenGL-first milestone is Linux-only and the engine's renderer interface should already be abstracted for game logic to be backend-agnostic.
- The audio backend choice (SDL3 audio vs. miniaudio) is low-risk to change later since audio is typically one of the more isolated engine subsystems.
- GLFW was not chosen over SDL3, but nothing here rules it out later for a narrower use case (e.g. if `vendor:wgpu`'s `glfwglue` proves smoother than `sdl3glue` in practice) — this is a reversible, low-stakes decision deferred to whenever the wasm/WebGPU port actually starts.

## Sources

- https://github.com/odin-lang/Odin (repo root, vendor/ and core/ directory listings via `gh api`)
- https://github.com/odin-lang/Odin/releases
- https://github.com/odin-lang/Odin/releases/tag/dev-2026-03
- https://github.com/odin-lang/Odin/releases/tag/dev-2026-06
- https://github.com/odin-lang/Odin/releases/tag/dev-2026-07a
- https://odin-lang.org/docs/faq/
- https://odin-lang.org/docs/install/
- https://odin-lang.org/docs/testing/
- https://odin-lang.org/news/moving-towards-a-new-core-os/
- https://odin-lang.org/showcase/
- https://odin-lang.org/showcase/solar_storm/
- https://odin-lang.org/showcase/cat_and_onion/
- https://odin-lang.org/showcase/embergen/
- https://github.com/odin-lang/Odin/tree/master/vendor/OpenGL
- https://github.com/odin-lang/Odin/tree/master/vendor/wgpu
- https://github.com/odin-lang/Odin/tree/master/vendor/sdl3
- https://github.com/odin-lang/Odin/tree/master/vendor/sdl2
- https://github.com/odin-lang/Odin/tree/master/vendor/glfw
- https://github.com/odin-lang/Odin/tree/master/vendor/miniaudio
- https://github.com/odin-lang/Odin/tree/master/vendor/directx
- https://github.com/odin-lang/Odin/tree/master/vendor/darwin
- https://github.com/odin-lang/Odin/tree/master/core/testing
- https://github.com/odin-lang/Odin/tree/master/core/sys/wasm/js
- https://github.com/odin-lang/Odin/blob/master/core/time/perf.odin
- https://github.com/odin-lang/Odin/blob/master/src/build_settings.cpp
- https://github.com/odin-lang/Odin/pull/3941
- https://github.com/odin-lang/Odin/discussions/3454
- https://github.com/odin-lang/Odin/issues/4127
- https://github.com/odin-lang/Odin/wiki/Compiler-Flags
- https://github.com/odin-lang/Odin/wiki/Odin-Libs
- https://github.com/odin-lang/Odin/blob/master/.github/workflows/ci.yml
- https://github.com/odin-lang/examples/tree/master/wgpu/glfw-triangle
- https://pkg.odin-lang.org/core/testing/
- https://pkg.odin-lang.org/vendor/wgpu/
- https://github.com/gfx-rs/wgpu-native/releases/tag/v29.0.1.1
- https://github.com/floooh/sokol-odin
- https://raw.githubusercontent.com/floooh/sokol-odin/main/README.md
- https://github.com/floooh/sokol
- https://github.com/gingerBill/odin-sokol
- https://github.com/karl-zylinski/odin-sokol-hot-reload-template
- https://github.com/karl-zylinski/odin-sokol-web
- https://wiki.libsdl.org/SDL3/CategoryGPU
- https://wiki.libsdl.org/SDL3/README-emscripten
- https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_DRIVER
- https://github.com/libsdl-org/SDL/issues/10768
- https://github.com/libsdl-org/SDL/pull/16020
- https://discourse.libsdl.org/t/is-wayland-really-default/61737
- https://discourse.libsdl.org/t/linux-sdl2-reports-wrong-display-size-when-using-wayland/49686
- https://github.com/glfw/glfw/issues/2562
- https://forum.odin-lang.org/t/sdl3-on-linux-only-working-with-sdl-video-driver-x11/1377
- https://forum.odin-lang.org/t/so-many-different-wasm-build-targets/790
- https://forum.odin-lang.org/t/wasm-executable-size-jumps-unexpectedly/1202
- https://itch.io/games/tag-odinlang
- https://itch.io/devlog/1140864/web-build-crash-fixes-jswasm
- https://github.com/karl-zylinski/the-legend-of-tuna
- https://github.com/karl-zylinski/odin-raylib-web
- https://github.com/thetarnav/odin-wasm
- https://github.com/wrapperup/cool-engine-odin
- https://github.com/laytan/odin-http
- https://github.com/FourteenBrush/odin-template/blob/main/Makefile
- https://github.com/marketplace/actions/setup-odin
- https://repology.org/project/odin-lang/versions
- https://archlinux.org/packages/extra/x86_64/odin/
- https://aur.archlinux.org/packages/odin-git
- https://store.steampowered.com/app/2781210/CAT__ONION/
- https://store.steampowered.com/app/2599800/Spanking_Runners/ (checked and excluded, see Notable shipped games section)
- https://github.com/KD-lab-Open-Source/Samogonki
- https://www.indiegameprogramming.com/2026/02/19/why-choose-odin-lang.html (unverified/weak source, marked as such where cited)

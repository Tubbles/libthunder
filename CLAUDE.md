# libthunder

Clean-room reimplementation of the Warcraft III engine plus a companion world editor, written in Odin. Linux first; Windows, macOS, and wasm/WebGPU portability is a standing design constraint. Parity target: WC3 patch 1.29b (the last MPQ-based version).

## Read this first

- `docs/README.md` indexes all project documentation. Consult it before starting any work item.
- `docs/process.md` defines the workflow: work items, subagent usage, review gates, testing bar.
- `docs/vision.md` states goals, phases, and the legal ground rules.
- `docs/decisions/` records settled decisions. Do not re-litigate them; supersede with a new numbered record if one must change.

## Hard rules

- Clean-room discipline: never copy code from other projects into this repo. corepunch/open-realm (MIT, author also gave explicit permission) may be read freely as a reference; other projects only within what their licenses allow, and license is verified before studying a codebase. Never consult leaked or decompiled Blizzard source.
- No Blizzard assets, data files, or excerpts of them are ever committed. Tests that need real assets load them from the git-ignored `data/` directory.
- Ground behavioral claims about the original engine in sources: documented format specs, community documentation, or measurements against the real game. Cite them in the relevant doc or test.
- Language: Odin. snake_case procedures and variables, Ada_Case types, no abbreviated identifiers.

## Layout

- `docs/` holds the living project documentation: plans, decisions, research, work items. The paper trail lives here.
- `src/` will hold engine, editor, and tool source (created when implementation starts; gets its own CLAUDE.md then).
- `data/`, `tmp/`, `work/` are git-ignored: game assets, scratch files, brainstorming documents.

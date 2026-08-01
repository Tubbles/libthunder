# Vision

libthunder is an open source clean-room reimplementation of the Warcraft III engine, plus a companion editor intended to match and eventually surpass the original World Editor.

## Goals, in order

1. Plan: establish the lay of the land of existing WC3 open source work, identify leverageable prior art, write plans and documentation.
2. Parity: implement the engine to feature parity against the official game assets (MPQ archives, patch 1.29b) that users supply from their own copies.
3. Extend: fix long-standing grievances of the original engine: input delay, maximum unit count, data type inconsistencies, lack of a low-level modding API.
4. Liberate: move away from the official assets so the game stands alone.

In parallel with the engine: build and maintain an editor comparable to, then surpassing, the original World Editor.

## Constraints

- Language: Odin (decision 0001).
- License: AGPL-3.0-or-later (decision 0002).
- Parity target: patch 1.29b, the last MPQ-based version (decision 0003).
- Monorepo: engine, editor, and tools together (decision 0004).
- Primary target: Linux. Windows, macOS, and wasm/WebGPU portability is a standing design constraint, not an afterthought.

## Legal ground rules

- Clean-room: no Blizzard code, no leaked or decompiled Blizzard source, ever. Behavior is reimplemented from documented formats, community documentation, and black-box observation of the real game.
- corepunch/open-realm is MIT licensed (verified 2026-08-01) and its author gave the project owner explicit permission to use it as a reference. Policy is still read-and-learn, not copy-paste.
- Other projects are consulted only within what their licenses allow. License is verified before studying any codebase.
- No Blizzard assets or excerpts of them are committed to this repo. Game data lives in the git-ignored data/ directory on each dev machine.
- This project is not affiliated with or endorsed by Blizzard Entertainment.

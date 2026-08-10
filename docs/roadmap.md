# Roadmap

Draft until the kickoff research in docs/research/ is reviewed. Phases overlap; the editor track runs alongside the engine track from Phase 1 onward, since both sit on the shared format libraries.

## Phase 0: bootstrap (current)

Repo scaffolding, docs system, kickoff decisions, research surveys, toolchain (pinned Odin, test harness, repeatable check script), asset acquisition for dev machines.

## Phase 1: data foundation

MPQ reading first, then the formats in dependency order (BLP, SLK/TXT gameplay data, war3map.* map internals, MDX models). Round-trip tests from day one (testing-strategy.md layer 1). This foundation serves engine, editor, and tools alike.

## Phase 2: sim core

Deterministic simulation: consistent numerics and RNG, game data model, orders/commands, pathing, combat, JASS execution. The real-engine oracle harnesses (testing-strategy.md layers 3 and 4) grow alongside it. Broken down in [plan-phase-2.md](plan-phase-2.md): four tracks driven by the headless-skirmish milestone, with numerics decided by research (WI-0013) and the sim built lockstep-ready with netcode deferred (decision 0006).

Headless mode is a named deliverable of this phase, not a byproduct: the sim builds and runs with no rendering, audio, or input dependency, driven entirely through a programmatic order/observation interface. Dedicated servers, CI oracle runs, fast-forward replay verification, and AI experimentation (see Phase 5) all sit on it, and it is cheap to have only if the sim is built that way from day one.

## Phase 3: presentation

Rendering (terrain, models, UI), audio, input. Backend per decision 0005: SDL3 for windowing/input/audio, OpenGL first behind a backend-agnostic renderer interface, vendor:wgpu as the later portability target.

## Phase 4: editor parity

World Editor parity features on top of the shared format and data libraries.

## Phase 5: extension

The grievance list: input delay, maximum unit count, data type inconsistencies, low-level modding API.

LLM-powered game AI scripts: a language model drives a player through the same programmatic order/observation interface that Phase 2's headless mode exposes, as an alternative to the classic JASS AI scripts. Headless mode is the enabler; this item is the extension-phase payoff.

## Phase 6: asset independence

Replacement assets; the game stands alone.

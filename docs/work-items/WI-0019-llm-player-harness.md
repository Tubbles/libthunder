# WI-0019: LLM player harness

Status: backlog

## Goal

A harness that lets an LLM play a headless game in real time as an alternative to scripted game AI: the model gets its own system prompt (persona, strategy, rules of engagement), reads the game state through the observation API, and issues orders through the command stream at whatever latency it manages, while the sim runs at game speed. Owner goal added 2026-08-11; recorded in the roadmap under Phase 5 with experimentation explicitly allowed to start earlier.

## Scope notes

- Architecture per decision 0006: the LLM player is just another command-stream producer and observation consumer; the sim neither knows nor cares that a model is attached, and layer-0 determinism is unaffected by the harness (the command stream it produces is recorded and replayable like any other).
- Real time, not turn-based: the sim does not wait for the model. The harness snapshots observations, invokes the model (first target: `claude -p` non-interactive CLI; keep the invocation pluggable so any CLI-invocable model works), parses the reply into orders, and submits them at the tick they arrive. Model latency simply manifests as slow APM.
- Observation rendering: game state serialized into a model-readable textual summary. Fog-of-war honesty (the model sees only what its player could see) is a design point to settle at implementation; start honest, since cheating defeats the experiment's point.
- Order vocabulary: a documented, versioned action grammar the system prompt teaches; the harness validates and rejects malformed orders rather than crashing.
- Per-player configuration: system prompt file, model/CLI choice, invocation cadence, token budget. Full transcripts logged per game for post-mortems.
- Experiments in scope once mechanics exist: LLM vs idle, LLM vs LLM (different prompts), later LLM vs scripted AI. Cost awareness: `claude -p` calls are metered; the harness supports capping invocations per game.
- Composes with WI-0018: a game with an LLM player attached is watchable live from the owner's phone.

## Acceptance criteria

- A headless game runs at game speed with one harness-driven player whose orders demonstrably originate from model output (transcript shows observation in, orders out).
- The sim's hashes for a game are reproducible by replaying the recorded command stream without the harness attached.
- Malformed model output never crashes the harness or the sim; it is logged and skipped.
- Two harness instances with different system prompts can play each other.
- System prompt, model choice, and cadence are configuration, not code.
- Passes scripts/check.sh for whatever lands in-repo; the harness may live under tools/ (layout decided at implementation).

## Verification

A logged LLM-vs-LLM game on a real melee map, replayed hash-identical from its command stream; results and a transcript excerpt logged here.

## Log

- 2026-08-11: created from the owner's LLM-player goal. Depends on WI-0014 (API), WI-0016 (real maps), and enough of Track C that orders do something; the ticket exists now so the command-stream and observation designs keep it in mind.

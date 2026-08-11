# WI-0018: spectator stream

Status: backlog

## Goal

A stateless, join-anytime video stream of a running headless game, watchable from a phone browser (the owner's Android device): connect whenever, see whatever the sim is doing right now: dev progress, live integration-test runs, demos. Owner goal added 2026-08-11; recorded in the roadmap under Phase 2.

## Scope notes

- Strictly a read-only consumer of the headless observation API (WI-0014); it must not be able to mutate sim state (decision 0006 boundary) and the sim must not depend on it existing.
- "Stateless" means the client carries no session: joining mid-game shows the current state immediately, disconnecting costs nothing, multiple viewers are fine.
- First cut: a server-rendered lightweight 2D view (terrain-colored minimap-style canvas, unit markers by player color, selection of what to follow) encoded as MJPEG over HTTP: universally playable in any browser with zero client code, trivially stateless, cheap to implement. Upgrade path (H.264/WebRTC for bandwidth, the Phase 3 renderer's frames as the source) is deliberately deferred.
- The test harness gets a flag to expose the stream during gated integration runs, so a sweep or layer-4 replay run can be watched live.
- LAN-first; exposure beyond the LAN is a security decision deferred until someone actually wants it, and the doc records that it was deferred on purpose.
- The 2-core dev machine constrains encoding ambition; MJPEG of a small canvas at modest FPS is chosen partly for that.

## Acceptance criteria

- A headless session with the stream enabled is viewable from a phone browser on the LAN by opening a URL; joining mid-run shows current state within a second.
- Two simultaneous viewers work; a viewer disconnecting/reconnecting does not disturb the sim or the other viewer.
- The sim's layer-0 determinism is unaffected by the stream being on or off (identical state hashes either way).
- An integration-test run with the harness flag set is watchable live.
- Passes scripts/check.sh.

## Verification

Watched from the owner's device on the LAN; determinism non-interference demonstrated by hash comparison; results logged here.

## Log

- 2026-08-11: created from the owner's spectator-stream goal. Depends on WI-0014's observation API; earliest useful the moment the layer-0 toy state exists, genuinely fun once WI-0016 instantiates real maps.

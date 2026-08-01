# WI-0003: Odin ecosystem survey

Status: in review (agent report landed 2026-08-01, awaiting grounding review)

## Goal

Assess Odin ecosystem readiness for a portable game engine and recommend a platform stack (windowing, rendering, audio) for Linux-first plus the planned wasm/WebGPU port. Feeds the pending rendering backend decision record.

## Acceptance criteria

- docs/research/odin-ecosystem.md exists, covering release/pinning practice, vendor libraries, the wasm story, rendering backend options with tradeoffs, windowing and audio options, testing story, build conventions, and shipped Odin projects.
- Ends with a recommended stack and a note on which decisions can be deferred.
- Every claim sourced or marked unverified.

## Verification

Grounding review pass per process.md, then a rendering/windowing/audio decision record proposed to the owner.

## Log

- 2026-08-01: created; research agent dispatched.
- 2026-08-01: agent report landed in docs/research/odin-ecosystem.md. Preliminary recommendation: SDL3 + OpenGL first with a backend-agnostic renderer interface, vendor:wgpu as the later portability target, pin an exact Odin release tag. Review pending.

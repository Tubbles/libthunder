# 0005: Rendering and platform stack

Date: 2026-08-01. Status: accepted (project owner decision, options presented from docs/research/odin-ecosystem.md).

## Context

Linux is the primary target now; Windows, macOS, and wasm/WebGPU ports are planned. The Odin ecosystem survey assessed four rendering backends (raw OpenGL, vendor:wgpu, sokol_gfx, SDL3 GPU) against that portability matrix.

## Decision

- Windowing and input: SDL3 via the official vendor:sdl3 binding.
- Rendering: OpenGL (vendor:OpenGL) for the Linux-first milestone, behind a backend-agnostic renderer interface owned by libthunder. The OpenGL backend is deliberately disposable.
- The wasm/Windows/macOS phase targets vendor:wgpu (official Odin package with a documented dual native-plus-browser code path); re-evaluate against sokol_gfx and SDL3 GPU when that phase actually starts, per the survey's deferral note.
- Audio: SDL3's audio subsystem to start; miniaudio is the designated fallback if audio must decouple from windowing (for example a headless dedicated server).

## Consequences

Game logic never touches GL directly; everything goes through the renderer interface so the eventual backend swap stays contained. One renderer rewrite is accepted as planned cost. The known SDL3-on-Wayland gotcha (blank window without an explicit present, documented in the ecosystem survey) must be tested early on this machine.

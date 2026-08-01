# 0001: Implementation language is Odin

Date: 2026-08-01. Status: accepted (project owner decision at kickoff).

## Context

The project owner chose Odin for the reimplementation: a systems language with manual memory control, strong C interop, official bindings for game-relevant libraries, and a design the owner wants to invest in.

## Decision

All engine, editor, and tool code is written in Odin. Third-party C libraries may be bound where unavoidable, preferring Odin's official vendor bindings.

## Consequences

Odin has no package manager, so third-party Odin code is vendored into the repo. The compiler version must be pinned (WI-0004). Ecosystem maturity for rendering, audio, and windowing is assessed in docs/research/odin-ecosystem.md before the backend decision record is written.

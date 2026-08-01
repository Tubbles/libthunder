# WI-0004: Toolchain bootstrap

Status: backlog

## Goal

A pinned Odin toolchain working on this machine plus a minimal buildable and testable source skeleton, so implementation work items can start.

## Acceptance criteria

- Odin compiler installed with the version pinned, documented, and checked by script.
- src/ skeleton with at least one package and one passing `odin test`.
- A repeatable check script (build plus tests) that a fresh clone can run.

## Verification

Fresh-clone dry run of the documented setup steps; check script exits zero.

## Log

- 2026-08-01: created. Odin is not installed on this machine (verified: `odin: command not found`). Installation approach to follow the docs/research/odin-ecosystem.md recommendation.

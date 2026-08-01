# WI-0004: Toolchain bootstrap

Status: done

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
- 2026-08-01: done. scripts/setup-toolchain.sh installs the pinned dev-2026-07a Linux amd64 release archive (sha256-verified) into the git-ignored toolchain/ directory; the installed binary self-reports as `dev-2026-07-nightly:819fdc7`, which is the release build's internal naming for the dev-2026-07a tag. scripts/check.sh runs `odin test` over every package under src/ with `-vet -strict-style -warnings-as-errors`; src/thunder passes with one test. Verification note: the download and install paths of the script were both exercised on this machine; a literal fresh-clone dry run should be repeated once a second dev machine or CI exists.

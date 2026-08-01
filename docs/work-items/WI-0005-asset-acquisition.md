# WI-0005: Game asset acquisition for testing

Status: done

## Goal

A repeatable, git-ignored way to get WC3 1.29b-era MPQ assets onto a dev machine for parity testing. No local installation exists yet.

## Context

corepunch/open-realm's `make download` fetches a ~1.2 GB installer from archive.org into its data/ folder (verified 2026-08-01 from the open-realm README). We want an equivalent for our git-ignored data/ directory, plus support for pointing at an existing legal installation instead.

## Acceptance criteria

- A script or documented steps produce a data/ directory whose MPQs the engine and tests can consume.
- Works from either a user-provided install path or a download source.
- Legal caveat documented: this repo never redistributes Blizzard assets; any download happens at the user's own discretion.
- Hashes of the resulting MPQs are recorded so the test corpus is stable across machines.

## Verification

Run the steps on this machine; the expected MPQ files exist and match recorded hashes.

## Log

- 2026-08-01: created from kickoff answer ("look at open-realm make download").
- 2026-08-01: done. scripts/download-game-data.sh mirrors open-realm's target (archive.org, Warcraft-III-1.29.2-enUS.zip) and also accepts an existing install path. Download ran clean; data/Warcraft III/ now holds War3.mpq, War3x.mpq, War3Local.mpq, War3xLocal.mpq, Deprecated.mpq, stock melee maps, a demo campaign, and World Editor.exe (relevant to testing-strategy layer 2). Hashes recorded in docs/asset-manifest.md.

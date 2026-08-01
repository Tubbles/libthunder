# 0004: Engine, editor, and tools live in one repository

Date: 2026-08-01. Status: accepted (project owner decision at kickoff).

## Context

The editor and engine share the format and data libraries, which will be in flux for a long time. Splitting repos now would make every format change a multi-repo dance.

## Decision

Monorepo: engine, editor, and CLI tools all live in libthunder as separate Odin packages sharing common libraries.

## Consequences

Cross-cutting format changes stay atomic. Package boundaries inside src/ must stay clean so a later split remains possible if ever wanted.

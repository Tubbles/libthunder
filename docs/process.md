# Process

How work gets done in this project. The project owner sets direction and answers design questions. Claude drives execution and project management. Subagents do scoped work under review.

## Work items

- Live in `docs/work-items/`, one file per item, named `WI-NNNN-short-slug.md`.
- Required sections: Status (backlog, in progress, in review, done, dropped), Goal, Acceptance criteria, Verification, Log.
- Acceptance criteria must be verifiable. "Works" is not a criterion; "round-trips every map in the corpus byte-identically" is.
- The file is the ticket: update Status and append to Log as work proceeds.

## Quality gates

- Every implementation work item ships with tests. Format code gets golden/corpus tests, sim code gets deterministic unit tests. Nothing lands with failing tests.
- When a work item is functionally complete, an independent review pass runs before it is marked done: a fresh reviewer (subagent or main line) checks the diff and tests against the acceptance criteria.
- Research and documentation work items get a grounding review: claims must carry sources, and license claims are spot-checked against the upstream repos.
- Cheap models may draft; nothing lands without review at full quality.

## Subagent usage

- Research and mechanical work is delegated to subagents to conserve context. Prompts must state the deliverable format and the grounding requirements.
- Subagents never commit. The main line reviews and commits.

## Documentation conventions

- Markdown: one paragraph per line, no manual re-wrapping.
- Decision records: `docs/decisions/NNNN-slug.md` with Context, Decision, Consequences. Owner decisions are recorded, not re-litigated; reopening one requires a new record superseding the old.
- Every research document ends with a Sources section of URLs. Unverifiable claims carry an explicit "unverified" marker.

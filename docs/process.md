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
- Work packages handed to a subagent are kept small and sharply defined: one format, one package, one bounded fix list. Two reasons, both learned 2026-08-10 when a large WI-0011 implementation agent was cut off mid-task by a session usage limit: a small package finishes comfortably inside a session limit, and a small well-defined task is one a cheaper model can carry. Split a work item into several sequential agent tasks rather than one large agent.
- Implementation and mechanical subagents run on Opus by default, not the main-line model. The main line writes the task definition at full quality; the subagent executes it; the independent review that gates every work item stays at full quality (per Quality gates above), so nothing lands on the cheaper model's judgment alone.
- A subagent cut off mid-task (session limit, crash) is revived by sending it a continuation message so it resumes from its own transcript; it should re-check on-disk state first, since a file can be half-written at the cutoff moment. Don't restart the task from scratch.

## Documentation conventions

- Markdown: one paragraph per line, no manual re-wrapping.
- Decision records: `docs/decisions/NNNN-slug.md` with Context, Decision, Consequences. Owner decisions are recorded, not re-litigated; reopening one requires a new record superseding the old.
- Every research document ends with a Sources section of URLs. Unverifiable claims carry an explicit "unverified" marker.

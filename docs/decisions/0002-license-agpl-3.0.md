# 0002: License is AGPL-3.0-or-later

Date: 2026-08-01. Status: accepted (project owner decision at kickoff).

## Context

The owner chose AGPL-3.0 at kickoff. It is the strongest copyleft: network use counts as distribution, which matters if the project ever grows hosted services (matchmaking, map repositories).

## Decision

The repository is licensed AGPL-3.0-or-later. The "or later" variant was an assumption by Claude, flagged to the owner at kickoff; tighten to AGPL-3.0-only with a superseding record if preferred.

## Consequences

Code from permissively licensed projects (MIT, BSD, Apache) could legally be incorporated with attribution, but the clean-room policy in vision.md still forbids copy-paste; the license compatibility only lowers the risk of studying such code. GPL and AGPL prior art can be studied without license conflict. Contributions are accepted under the same license.

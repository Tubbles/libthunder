# src/

Odin source tree. One directory here = one Odin package.

- `thunder/` is the root engine package (currently a version-constant stub from WI-0004).
- Build and test everything with `scripts/check.sh`; it enforces `-vet -strict-style -warnings-as-errors`, so match official Odin style (tab indentation) or the gate fails.
- Toolchain is repo-local and pinned: `scripts/setup-toolchain.sh` installs the exact tagged release into the git-ignored `toolchain/` directory. Never rely on a system-wide odin.
- Naming: snake_case procedures and variables, Ada_Case types, no abbreviated identifiers (`index` not `i`, `buffer` not `buf`).
- Tests live in the same package as the code they test, in `*_test.odin` files with `@(test)` procedures. Every new package ships with tests from its first commit.

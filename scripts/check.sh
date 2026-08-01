#!/usr/bin/env bash
# The quality gate entry point: builds and tests every Odin package under
# src/. A fresh clone runs scripts/setup-toolchain.sh once, then this.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
odin="${repository_root}/toolchain/odin/odin"

if [[ ! -x "${odin}" ]]; then
    echo "Odin toolchain missing; run scripts/setup-toolchain.sh first" >&2
    exit 1
fi

mkdir -p "${repository_root}/tmp"

vet_flags=(-vet -strict-style -warnings-as-errors)

exit_status=0
for package_directory in "${repository_root}"/src/*/; do
    echo "== ${package_directory}"
    "${odin}" test "${package_directory}" \
        -out:"${repository_root}/tmp/test_binary" \
        "${vet_flags[@]}" || exit_status=1
done
exit "${exit_status}"

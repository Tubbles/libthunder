#!/usr/bin/env bash
# Installs the pinned Odin toolchain into toolchain/odin (git ignored).
# The version is pinned deliberately: Odin is pre-1.0 and ships breaking
# changes in its monthly releases (see docs/research/odin-ecosystem.md).
# Linux amd64 only for now; extend when another dev platform appears.
set -euo pipefail

odin_release_tag="dev-2026-07a"
archive_name="odin-linux-amd64-${odin_release_tag}.tar.gz"
download_url="https://github.com/odin-lang/Odin/releases/download/${odin_release_tag}/${archive_name}"
expected_sha256="32a7678abc66f1af7353abb5b0b5da47d94b7e663f6d250df29bc9117e864c10"

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_directory="${repository_root}/toolchain/odin"
archive_path="${repository_root}/tmp/${archive_name}"

if [[ -x "${install_directory}/odin" ]]; then
    echo "Odin already installed at ${install_directory}"
    "${install_directory}/odin" version
    exit 0
fi

mkdir -p "${repository_root}/tmp"

if [[ ! -f "${archive_path}" ]]; then
    echo "Downloading ${download_url}"
    curl -fSL -o "${archive_path}" "${download_url}"
fi

echo "${expected_sha256}  ${archive_path}" | sha256sum --check --quiet

mkdir -p "${install_directory}"
tar xzf "${archive_path}" --strip-components=1 -C "${install_directory}"
chmod +x "${install_directory}/odin"

"${install_directory}/odin" version

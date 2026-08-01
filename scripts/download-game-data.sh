#!/usr/bin/env bash
# Populates the git-ignored data/ directory with Warcraft III 1.29-era
# game files for parity testing, mirroring corepunch/open-realm's
# `make download` target (same archive.org source, patch 1.29.2).
#
# This repository never redistributes Blizzard assets; downloading the
# archive.org copy happens at the user's own discretion. If you already
# have a legal installation, point the script at it instead:
#   scripts/download-game-data.sh /path/to/existing/warcraft3
set -euo pipefail

archive_url="https://archive.org/download/warcraft-iii-installer-enus/Warcraft-III-1.29.2-enUS.zip"
archive_name="Warcraft-III-1.29.2-enUS.zip"

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
data_directory="${repository_root}/data"
archive_path="${repository_root}/tmp/${archive_name}"

if [[ $# -ge 1 ]]; then
    source_install="$1"
    echo "Copying game files from ${source_install}"
    mkdir -p "${data_directory}"
    cp -r --update=none "${source_install}/." "${data_directory}/"
    exit 0
fi

mkdir -p "${repository_root}/tmp" "${data_directory}"

if [[ ! -f "${archive_path}" ]]; then
    echo "Downloading ${archive_url}"
    curl -fL -o "${archive_path}" "${archive_url}"
fi

unzip -o "${archive_path}" -d "${data_directory}"

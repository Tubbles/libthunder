# 0003: Parity target is Warcraft III patch 1.29b

Date: 2026-08-01. Status: accepted (owner proposed 1.29b conditional on verification; verified the same day).

## Context

Goal 2 (feature parity against official MPQ assets) needs a concrete patch to define what "parity" means. The owner proposed 1.29b, matching what open-realm supports, conditional on double-checking that it is the last MPQ-based version.

## Decision

Target patch 1.29b for the parity phase.

## Reasoning, verified 2026-08-01

Patch 1.30.0 moved game data storage from MPQ archives to CASC, making the 1.29 line the last MPQ-based one. Sources: Hive Workshop threads "Listfile for Warcraft 3 (1.30+)" (https://www.hiveworkshop.com/threads/listfile-for-warcraft-3-1-30.307111/) and "Where the heck is the .mpq?" (https://www.hiveworkshop.com/threads/where-the-heck-is-the-mpq.308237/). Maps remained MPQ-based even after 1.30, so map-format work carries forward regardless of engine patch. corepunch/open-realm states ongoing support for 1.29b (https://github.com/corepunch/open-realm), which keeps it maximally useful as a reference. The 1.29 line also brought 24-player support, relevant to the later extension phase.

## Consequences

The engine reads MPQ, not CASC. Format research and test corpora pin to 1.29b behavior; deviations observed on other patches are recorded when discovered. Reforged compatibility is out of scope for the parity phase.

---
name: repo-change-hygiene
description: Apply repository hygiene when changing metadata, paths, or directory layout so configs, docs, and scripts stay in sync.
---

# Repo Change Hygiene

Use this skill when reorganizing files, adding metadata lists, or changing path
contracts.

## Metadata changes

- Add new metadata files under the appropriate `metadata/` subdirectory.
- Wire new metadata into scripts/pipelines via config params.
- Do not hardcode sample IDs in scripts.
- Keep raw reference inputs under `refdata/` and generated assets under
  `derived_data/refdata/`; do not relocate reference inputs into step outputs.

## Directory/path changes

- Update all affected references in scripts, pipeline configs, and wrappers.
- Keep output policy intact:
  - step outputs/reports -> `outs/<analysis>/<step>/...`
  - MultiQC HTML -> `results/reports/<analysis>/...`

## Documentation sync

- Update `docs/CONTENTS.md` after directory-structure changes.
- Keep AGENTS-layer docs free of duplicated policy text; link to skills instead.
- For new technical docs, keep content concise and include concrete paths and
  expected outputs.

## Verification

1. `rg` finds no stale paths after move/rename.
2. Wrapper runs still place outputs/reports in the expected locations.
3. Commit the change set (no push).

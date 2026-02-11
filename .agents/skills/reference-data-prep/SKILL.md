---
name: reference-data-prep
description: Prepare and validate shared reference assets used by analysis pipelines, including Centrifuge DB and derived PAVE feature/BED tables.
---

# Reference Data Preparation

Use this skill when missing or stale reference assets cause step failures.

## Centrifuge Database

- Builder script: `scripts/taxonomy_assignment/build_centrifuge_db.sh`.
- Target root: `refdata/centrifuge/`.
- Ensure `config/user.config` points to the generated index/taxdump paths.

## Derived PAVE Feature Tables

- Generator: `scripts/pave/gff3_to_features_tsv.run_all.sh`.
- Inputs: `refdata/pave/gff3`.
- Outputs: `derived_data/refdata/pave/features_tsv`.
- Used by mapping-vs-PAVE coverage summaries.

## Derived PAVE BED Files

- Generator: `scripts/pave/gff3_to_bed.run_all.sh`.
- Inputs: `refdata/pave/gff3`.
- Outputs: `derived_data/refdata/pave/bed`.
- Used by variant extraction/comparison.

## Validation

1. Generated directories exist and are non-empty.
2. Files are in `derived_data/refdata/...` (not copied into step outputs).
3. Pipelines resolve these paths via config, without hardcoded user paths.

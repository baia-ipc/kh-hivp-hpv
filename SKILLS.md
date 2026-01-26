# SKILLS

This file catalogs the repository's workflows (what exists and where). For how to run or troubleshoot them, see `OPERATIONS.md`.

## Core conventions (scope only)

- Configuration lives in `config/` (no hardcoded paths in scripts).
- Sample lists and other hardcoded data live in `metadata/`.
- Outputs live under each step's `output/` and `reports/` directories.

## Skill: centrifuge bucketing (Nextflow)

- Scope: read classification, bucketing, and summary tables.
- Pipeline: `pipelines/centrifuge_bucketing.nf` and `pipelines/centrifuge_bucketing_all.nf`.
- Inputs: `metadata/samples-input1.tsv` or `metadata/samples-input2.tsv` plus the Centrifuge index/taxdump.
- Outputs:
  - analysis-input1: `analysis-input1/001.0.centrifuge/output` and `reports`
  - analysis-input2: `analysis-input2/001.0.bucketing/output` and `reports`

## Skill: bowtie vs PAVE mapping and reports

- Scope: mapping and rough strain assignment.
- Locations:
  - analysis-input1: `analysis-input1/002.0.bowtie_vs_pave`
  - analysis-input2: `analysis-input2/002.0.mapping_vs_pave`
- Inputs: bucketed FASTQs from the corresponding step 001 output.
- Outputs: `output/` (per-sample) and `reports/` (aggregates).

## Skill: VirStrain reports

- Scope: VirStrain-based strain reports (analysis-input1 only).
- Location: `analysis-input1/003.0.virstrain`.
- Inputs: bucketed FASTQs from `analysis-input1/001.0.centrifuge/output`.
- Outputs: `output/` and `reports/`.

## Skill: E6/E7 sub-analyses

- Scope: separate E6 and E7 bowtie analyses (analysis-input1 only).
- Locations:
  - `analysis-input1/004.0.bowtie_vs_pave.E6`
  - `analysis-input1/005.0.bowtie_vs_pave.E7`
- Inputs: bucketed FASTQs from step 001.
- Outputs: `output/` and `reports/`.

## Skill: phylogenetic trees (HPV16/HPV18)

- Scope: tree generation for HPV16 and HPV18.
- Locations:
  - `analysis-input2/003.0.hpv16_tree`
  - `analysis-input2/004.0.hpv18_tree`
- Inputs: mapping outputs and curated reference sets in each step's `input/`.
- Outputs: alignment and tree artifacts under each step directory.

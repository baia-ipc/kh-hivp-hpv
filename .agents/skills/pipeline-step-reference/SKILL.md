---
name: pipeline-step-reference
description: Repository capability reference for analysis steps (centrifuge bucketing, mapping vs PAVE, variant analysis, VirStrain, phylogenetic trees), including entrypoints, key inputs/outputs, and helper scripts.
---

# Pipeline Step Reference

Use this skill when you need a quick, accurate map of what each step does and
where its key inputs/outputs are.

## 01. Centrifuge Bucketing

- Pipelines: `pipelines/centrifuge_bucketing.nf`,
  `pipelines/centrifuge_bucketing_all.nf`.
- Inputs: sample sheets in `metadata/seq_samples/` plus Centrifuge index/taxdump.
- Outputs: `outs/<analysis>/01.bucketing/...` and step reports under `reports/`.
- MultiQC helper: `scripts/taxonomy_assignment/prepare_centrifuge_multiqc_inputs.py`.

## 02. Mapping vs PAVE

- Pipeline: `pipelines/bowtie_vs_pave.nf`.
- Inputs: step-01 bucketed FASTQs + PAVE references (`refdata/pave/`) and
  derived PAVE assets (`derived_data/refdata/pave/`).
- Outputs: `outs/<analysis>/02.mapping_vs_pave/...`.
- Policy: step-02 MultiQC omits `General Statistics`, `Samtools`, `Bcftools`.
- MultiQC helper: `scripts/coverage/prepare_bowtie_multiqc_inputs.py`.

## 03. Variant Analysis

- Pipeline: `pipelines/variant_analysis.nf`.
- Inputs: step-02 mapping outputs + PAVE references/derived assets.
- Outputs: `outs/<analysis>/03.variant_analysis/...`.
- Policy: includes `General Statistics`, `Samtools`, `Bcftools` at report end;
  exclude `Undetermined*` downstream.
- Helpers:
  - `scripts/variants/prepare_variant_multiqc_inputs.py`
  - `scripts/variants/prepare_database_multiqc_tables.py`
  - `scripts/variants/reorder_multiqc_sections.py`

## 04. VirStrain (optional prelim)

- Pipeline: `pipelines/virstrain.nf`.
- Environment: use the VirStrain-specific env wiring from
  `config/pipelines/virstrain.config` / `pipelines/conda_env/virstrain.env.yml`.
- Inputs: step-01 bucketed FASTQs (`params.bucket_tid` filtering).
- Outputs: `outs/prelim_analysis/04.virstrain/...`.
- Policy: exclude `Undetermined*` inputs.
- MultiQC helper: `scripts/virstrain/prepare_virstrain_multiqc_inputs.py`.

## 04/05. Phylogenetic Trees (targeted)

- Pipeline: `pipelines/phylo_tree.nf`.
- Steps:
  - `outs/targeted_analysis/04.hpv16_tree`
  - `outs/targeted_analysis/05.hpv18_tree`
- Inputs: derived tree refdata under `derived_data/refdata/hpv16_tree` and
  `derived_data/refdata/hpv18_tree`; outgroup/lineage metadata under
  `metadata/hpv16_tree/` and `metadata/hpv18_tree/`.
- Outputs: tree artifacts in step directory; `phylo_tree.svg/.png` at step
  root; `reports/phylo_tree_summary.multiqc.tsv` under reports.

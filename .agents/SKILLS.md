# SKILLS

Catalog of what exists (scope + where). This is a map of capabilities and locations, not a how-to.

Rules:
- Do not add run commands or troubleshooting here (put them in `.agents/OPERATIONS.md`).
- Do not describe step order/dependencies here (put them in `.agents/WORKFLOWS.md`).

## Core conventions (scope only)

- User-editable configuration lives in `config/` (no hardcoded paths in scripts); step path configs live under `bin/config/`; technical Nextflow config (including derived refdata paths) lives under `config/pipelines/`, and Conda env definitions live under `pipelines/conda_env/`.
- Step/analysis wrapper scripts live under `bin/` (wrappers around Nextflow pipelines).
- Sample lists and other hardcoded data live in `metadata/`.
- Reference inputs live in `refdata/`; derived reference assets live in `intermediate_files/refdata/` (do not place reference inputs under analysis step directories).
- Centrifuge database build script lives at `scripts/build_centrifuge_db.sh` (outputs under `refdata/centrifuge/`).
- Outputs live under each step's `output/` and `reports/` directories.
- MultiQC reports are published to each step’s `reports/` (tree steps use `output/reports/`), with the process writing `multiqc_report.html` at the workdir root and `publishDir` targeting the final reports directory.
- MultiQC methods sections include primary literature references for the tools used in each step (see the step-specific `pipelines/multiqc/*.multiqc.yml`).
- Custom MultiQC sections and tables are defined in `pipelines/multiqc/*.multiqc.yml` under `custom_data` with explicit `plot_type`, and TSV tables are wired via `sp:` search patterns.
- Nextflow execution can be sensitive to the caller environment; when documenting run commands, assume Java 17+ and avoid relying on an activated Conda env unless explicitly required (see .agents/OPERATIONS.md for the concrete invocation pattern).

## Skill: centrifuge bucketing (Nextflow)

- Scope: read classification, bucketing, and summary tables.
- Entry points: `pipelines/centrifuge_bucketing.nf`, `pipelines/centrifuge_bucketing_all.nf`.
- Where:
  - preliminary-analysis-all-patients: `preliminary-analysis-all-patients/001.0.centrifuge`
  - targeted-analysis-hpv16-hpv18: `targeted-analysis-hpv16-hpv18/001.0.bucketing`
- Inputs: `metadata/samples-input1.tsv` or `metadata/samples-input2.tsv` (normalized `sample_id` + raw `fastq_sample_id`) plus Centrifuge index/taxdump.
- Outputs:
  - preliminary-analysis-all-patients: `preliminary-analysis-all-patients/001.0.centrifuge/output`, `preliminary-analysis-all-patients/001.0.centrifuge/reports`
  - targeted-analysis-hpv16-hpv18: `targeted-analysis-hpv16-hpv18/001.0.bucketing/output`, `targeted-analysis-hpv16-hpv18/001.0.bucketing/reports`

## Skill: bowtie vs PAVE mapping and reports

- Scope: mapping and rough strain assignment.
- Entry points: `pipelines/bowtie_vs_pave.nf` (config: `config/user.config`).
- Where:
  - preliminary-analysis-all-patients: `preliminary-analysis-all-patients/002.0.bowtie_vs_pave`
  - targeted-analysis-hpv16-hpv18: `targeted-analysis-hpv16-hpv18/002.0.mapping_vs_pave`
- Inputs: bucketed FASTQs from the corresponding step 001 output; bucket selection via `params.bucket_tid` in `config/pipelines/bowtie_vs_pave.config`.
- Reference assets: PAVE FASTA/GFF3 under `refdata/pave/`, plus derived BEDs and feature tables under `intermediate_files/refdata/pave/`.
- Outputs: per-step `output/` and `reports/` under the locations above.

## Skill: VirStrain reports

- Scope: VirStrain-based strain reports (preliminary-analysis-all-patients only).
- Entry points: `pipelines/virstrain.nf` (config: `config/user.config`).
- Where: `preliminary-analysis-all-patients/003.0.virstrain`.
- Inputs: bucketed FASTQs from `preliminary-analysis-all-patients/001.0.centrifuge/output`; bucket selection via `params.bucket_tid` in `config/pipelines/virstrain.config`.
- Outputs: `preliminary-analysis-all-patients/003.0.virstrain/output`, `preliminary-analysis-all-patients/003.0.virstrain/reports`.

## Skill: E6/E7 sub-analyses

- Scope: separate E6 and E7 gene-only mapping analyses (preliminary-analysis-all-patients only).
- Entry points: `pipelines/pave_gene_mapping.nf` (config: `bin/config/preliminary-analysis-all-patients.config`, profiles `preliminary_pave_e6` and `preliminary_pave_e7`).
- Where:
  - E6: `preliminary-analysis-all-patients/004.0.bowtie_vs_pave.E6`
  - E7: `preliminary-analysis-all-patients/005.0.bowtie_vs_pave.E7`
- Inputs: bucketed FASTQs from `preliminary-analysis-all-patients/001.0.centrifuge/output`; bucket selection via `params.bucket_tid` in `config/pipelines/pave_gene_mapping.config`.
- Outputs: per-step `output/` and `reports/` under the locations above.

## Skill: phylogenetic trees (HPV16/HPV18)

- Scope: tree generation for HPV16 and HPV18.
- Entry points: `pipelines/phylo_tree.nf` (user config: `config/user.config`; step path config: `bin/config/targeted-analysis-hpv16-hpv18.config` with profiles `targeted_hpv16_tree`, `targeted_hpv18_tree`).
- Where:
  - HPV16: `targeted-analysis-hpv16-hpv18/003.0.hpv16_tree`
  - HPV18: `targeted-analysis-hpv16-hpv18/004.0.hpv18_tree`
- Inputs: curated tree inputs under `intermediate_files/refdata/hpv16_tree` and `intermediate_files/refdata/hpv18_tree` (prepared from `refdata/hpv16_tree` and `refdata/hpv18_tree`).
- Outputs: alignment and tree artifacts under each step `output/`.

## Skill: SNPs samples vs database

- Scope: extract Cambodian HPV16/HPV18 references, call E6/E7 SNPs, and compare against lineage and sample SNPs.
- Entry points: `pipelines/cambodia_snps.nf` (config: `config/user.config`).
- Where: `targeted-analysis-hpv16-hpv18/005.0.snps_samples_vs_db`.
- Inputs:
  - Selected reference sets under `intermediate_files/refdata/hpv16_tree` and `intermediate_files/refdata/hpv18_tree`
  - Sample variants from `targeted-analysis-hpv16-hpv18/002.0.mapping_vs_pave/reports/E6_E7_variants.tsv`
- Outputs: `targeted-analysis-hpv16-hpv18/005.0.snps_samples_vs_db/output`, `targeted-analysis-hpv16-hpv18/005.0.snps_samples_vs_db/reports`.

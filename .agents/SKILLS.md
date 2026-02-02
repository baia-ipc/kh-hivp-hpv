# SKILLS

Catalog of what exists (scope + where). This is a map of capabilities and locations, not a how-to.

Rules:
- Do not add run commands or troubleshooting here (put them in `.agents/OPERATIONS.md`).
- Do not describe step order/dependencies here (put them in `.agents/WORKFLOWS.md`).

## Core conventions (scope only)

- User-editable configuration lives in `config/` (no hardcoded paths in scripts); technical Nextflow config lives under `pipelines/config/`, and Conda env definitions live under `pipelines/conda_env/`.
- Sample lists and other hardcoded data live in `metadata/`.
- Reference inputs live in `refdata/raw/`; derived reference assets live in `refdata/derived/` (do not place reference inputs under analysis step directories).
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
  - analysis-input1: `analysis-input1/001.0.centrifuge`
  - analysis-input2: `analysis-input2/001.0.bucketing`
- Inputs: `metadata/samples-input1.tsv` or `metadata/samples-input2.tsv` (normalized `sample_id` + raw `fastq_sample_id`) plus Centrifuge index/taxdump.
- Outputs:
  - analysis-input1: `analysis-input1/001.0.centrifuge/output`, `analysis-input1/001.0.centrifuge/reports`
  - analysis-input2: `analysis-input2/001.0.bucketing/output`, `analysis-input2/001.0.bucketing/reports`

## Skill: bowtie vs PAVE mapping and reports

- Scope: mapping and rough strain assignment.
- Entry points: `pipelines/bowtie_vs_pave.nf` (config: `config/bowtie_vs_pave.config`).
- Where:
  - analysis-input1: `analysis-input1/002.0.bowtie_vs_pave`
  - analysis-input2: `analysis-input2/002.0.mapping_vs_pave`
- Inputs: bucketed FASTQs from the corresponding step 001 output; bucket selection in `config/pave_bucket_tid.txt`.
- Reference assets: PAVE FASTA/GFF3/BED under `refdata/raw/pave/`, plus derived feature tables under `refdata/derived/pave/features_tsv`.
- Outputs: per-step `output/` and `reports/` under the locations above.

## Skill: VirStrain reports

- Scope: VirStrain-based strain reports (analysis-input1 only).
- Entry points: `pipelines/virstrain.nf` (config: `config/virstrain.config`).
- Where: `analysis-input1/003.0.virstrain`.
- Inputs: bucketed FASTQs from `analysis-input1/001.0.centrifuge/output`; bucket selection in `config/pave_bucket_tid.txt`.
- Outputs: `analysis-input1/003.0.virstrain/output`, `analysis-input1/003.0.virstrain/reports`.

## Skill: E6/E7 sub-analyses

- Scope: separate E6 and E7 gene-only mapping analyses (analysis-input1 only).
- Entry points: `pipelines/pave_gene_mapping.nf` (configs: `config/pave_e6.config`, `config/pave_e7.config`).
- Where:
  - E6: `analysis-input1/004.0.bowtie_vs_pave.E6`
  - E7: `analysis-input1/005.0.bowtie_vs_pave.E7`
- Inputs: bucketed FASTQs from `analysis-input1/001.0.centrifuge/output`; bucket selection in `config/pave_bucket_tid.txt`.
- Outputs: per-step `output/` and `reports/` under the locations above.

## Skill: phylogenetic trees (HPV16/HPV18)

- Scope: tree generation for HPV16 and HPV18.
- Entry points: `pipelines/phylo_tree.nf` (configs: `config/hpv16_tree.config`, `config/hpv18_tree.config`).
- Where:
  - HPV16: `analysis-input2/003.0.hpv16_tree`
  - HPV18: `analysis-input2/004.0.hpv18_tree`
- Inputs: curated tree inputs under `refdata/derived/hpv16_tree` and `refdata/derived/hpv18_tree` (prepared from `refdata/raw/hpv16_tree` and `refdata/raw/hpv18_tree`).
- Outputs: alignment and tree artifacts under each step `output/`.

## Skill: Cambodia SNP comparison

- Scope: extract Cambodian HPV16/HPV18 references, call E6/E7 SNPs, and compare against lineage and sample SNPs.
- Entry points: `pipelines/cambodia_snps.nf` (config: `config/cambodia_snps.config`).
- Where: `analysis-input2/005.0.cambodia_snps`.
- Inputs:
  - Selected reference sets under `refdata/derived/hpv16_tree` and `refdata/derived/hpv18_tree`
  - Sample variants from `analysis-input2/002.0.mapping_vs_pave/reports/E6_E7_variants.tsv`
- Outputs: `analysis-input2/005.0.cambodia_snps/output`, `analysis-input2/005.0.cambodia_snps/reports`.

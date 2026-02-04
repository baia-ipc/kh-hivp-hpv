# SKILLS

Catalog of what exists (scope + where). This is a map of capabilities and locations, not a how-to.

Rules:
- Do not add run commands or troubleshooting here (put them in `.agents/OPERATIONS.md`).
- Do not describe step order/dependencies here (put them in `.agents/WORKFLOWS.md`).

## Core conventions (scope only)

- User-editable configuration lives in `config/` (no hardcoded paths in scripts); step path configs live under `config/analyses/`; technical Nextflow config (including derived refdata paths) lives under `config/pipelines/`, and Conda env definitions live under `pipelines/conda_env/`.
- Step/analysis wrapper scripts live under `bin/` (wrappers around Nextflow pipelines).
- Raw FASTQ inputs live under `input_reads/` (symlinks or folders to external data).
- Script utilities live under `scripts/` and are grouped by concern in subdirectories (taxonomy_assignment, top_strains, coverage, variants, pave, virstrain, phylo_tree).
- Sample lists and other hardcoded data live in `metadata/`.
- Reference inputs live in `refdata/`; derived reference assets live in `derived_data/refdata/` (do not place reference inputs under analysis step directories).
- Shared Bowtie/VirStrain indices live under `derived_data/indices/` (Bowtie index + preliminary/virstrain).
- Centrifuge database build script lives at `scripts/taxonomy_assignment/build_centrifuge_db.sh` (outputs under `refdata/centrifuge/`).
- Outputs live under each step's `output/` and `reports/` directories.
- MultiQC reports are published to each step’s `reports/` (tree steps use `output/reports/`), with the process writing `multiqc_report.html` at the workdir root and `publishDir` targeting the final reports directory.
- MultiQC methods sections include primary literature references for the tools used in each step (see the step-specific `pipelines/multiqc/*.multiqc.yml`).
- Custom MultiQC sections and tables are defined in `pipelines/multiqc/*.multiqc.yml` under `custom_data` with explicit `plot_type`, and TSV tables are wired via `sp:` search patterns.
- Nextflow execution can be sensitive to the caller environment; when documenting run commands, assume Java 17+ and avoid relying on an activated Conda env unless explicitly required (see .agents/OPERATIONS.md for the concrete invocation pattern).

## Skill: centrifuge bucketing (Nextflow)

- Scope: read classification, bucketing, and summary tables.
- Entry points: `pipelines/centrifuge_bucketing.nf`, `pipelines/centrifuge_bucketing_all.nf`.
- Where:
  - prelim_analysis: `prelim_analysis/01.bucketing`
  - targeted_analysis: `targeted_analysis/01.bucketing`
- Inputs: `metadata/samples-input1.tsv` or `metadata/samples-input2.tsv` (normalized `sample_id` + raw `fastq_sample_id`) plus Centrifuge index/taxdump.
- Outputs:
  - prelim_analysis: `prelim_analysis/01.bucketing/output`, `prelim_analysis/01.bucketing/reports`
  - targeted_analysis: `targeted_analysis/01.bucketing/output`, `targeted_analysis/01.bucketing/reports`

## Skill: mapping vs PAVE (Bowtie2)

- Scope: mapping and rough strain assignment.
- Entry points: `pipelines/bowtie_vs_pave.nf` (config: `config/user.config`).
- Where:
  - prelim_analysis: `prelim_analysis/02.mapping_vs_pave`
  - targeted_analysis: `targeted_analysis/02.mapping_vs_pave`
- Inputs: bucketed FASTQs from the corresponding step 01 output; bucket selection via `params.bucket_tid` in `config/pipelines/bowtie_vs_pave.config`.
- Reference assets: PAVE FASTA/GFF3 under `refdata/pave/`, plus derived BEDs and feature tables under `derived_data/refdata/pave/`.
- Outputs: per-step `output/` and `reports/` under the locations above (including strain assignment + coverage table in step 02 reports).

## Skill: variant analysis

- Scope: aggregate E6/E7 variants, variant effects, optional lineage SNP comparison, and (targeted only) optional database comparison.
- Entry points: `pipelines/variant_analysis.nf` (config: `config/user.config`).
- Where:
  - prelim_analysis: `prelim_analysis/03.variant_analysis`
  - targeted_analysis: `targeted_analysis/03.variant_analysis`
- Inputs: mapping outputs from step 02 (`*/02.mapping_vs_pave/output`) plus PAVE reference assets under `refdata/pave/` and `derived_data/refdata/pave/`.
- Outputs: `reports/` under the locations above (E6/E7 variants, variant effects, lineage SNP comparison, database comparison tables when enabled, MultiQC).

## Skill: VirStrain reports (optional)

- Scope: VirStrain-based strain reports (prelim_analysis only).
- Entry points: `pipelines/virstrain.nf` (config: `config/user.config`).
- Where: `prelim_analysis/04.virstrain`.
- Inputs: bucketed FASTQs from `prelim_analysis/01.bucketing/output`; bucket selection via `params.bucket_tid` in `config/pipelines/virstrain.config`.
- Outputs: `prelim_analysis/04.virstrain/output`, `prelim_analysis/04.virstrain/reports`.

## Skill: phylogenetic trees (HPV16/HPV18)

- Scope: tree generation for HPV16 and HPV18.
- Entry points: `pipelines/phylo_tree.nf` (user config: `config/user.config`; step path config: `config/analyses/targeted_analysis.config` with profiles `targeted_hpv16_tree`, `targeted_hpv18_tree`).
- Where:
  - HPV16: `targeted_analysis/04.hpv16_tree`
  - HPV18: `targeted_analysis/05.hpv18_tree`
- Inputs: curated tree inputs under `derived_data/refdata/hpv16_tree` and `derived_data/refdata/hpv18_tree` (prepared from `refdata/hpv16_tree` and `refdata/hpv18_tree`).
- Derived inputs are generated by the pipeline when missing or older than the raw `refdata` inputs.
- Outputs: alignment and tree artifacts under each step `output/`, plus `output/reports/phylo_tree.svg` (PNG fallback) and `output/reports/phylo_tree_summary.multiqc.tsv`.

# SKILLS

Catalog of what exists (scope + where). This is a map of capabilities and locations, not a how-to.

Rules:
- Do not add run commands or troubleshooting here (put them in `.agents/OPERATIONS.md`).
- Do not describe step order/dependencies here (put them in `.agents/WORKFLOWS.md`).

## Core conventions (scope only)

- User-editable configuration lives in `config/` (no hardcoded paths in scripts); step path configs live under `config/analyses/`; technical Nextflow config (including derived refdata paths) lives under `config/pipelines/`, and Conda env definitions live under `pipelines/conda_env/`.
- Step/analysis wrapper scripts live under `bin/` (wrappers around Nextflow pipelines), with per-step parameters stored in `config/steps/*.json`.
- Raw FASTQ inputs live under `input_reads/` (symlinks or folders to external data).
- Script utilities live under `scripts/` and are grouped by concern in subdirectories (taxonomy_assignment, top_strains, coverage, variants, pave, virstrain, phylo_tree).
- Reusable local agent skill specs live under `.agents/skills/`.
- Sample lists and other hardcoded data live under `metadata/` subdirectories.
- Reference inputs live in `refdata/`; derived reference assets live in `derived_data/refdata/` (do not place reference inputs under analysis step directories).
- Curated output copies live under `results/` (selected outputs tracked for sharing/review).
- Shared Bowtie/VirStrain indices live under `derived_data/indices/` (Bowtie index + preliminary/virstrain).
- Centrifuge database build script lives at `scripts/taxonomy_assignment/build_centrifuge_db.sh` (outputs under `refdata/centrifuge/`).
- Outputs live under `outs/<analysis>/<step>/` with non‑MultiQC reports under `outs/<analysis>/<step>/reports/`.
- MultiQC reports are published under `results/reports/<analysis>/`.
- MultiQC methods sections include primary literature references for the tools used in each step (see the step-specific `pipelines/multiqc/*.multiqc.yml`).
- Custom MultiQC sections and tables are defined in `pipelines/multiqc/*.multiqc.yml` under `custom_data` with explicit `plot_type`, and TSV tables are wired via `sp:` search patterns.
- Nextflow execution can be sensitive to the caller environment; when documenting run commands, assume Java 17+ and avoid relying on an activated Conda env unless explicitly required (see .agents/OPERATIONS.md for the concrete invocation pattern).

## Skill: Nextflow sandbox execution contract

- Scope: stable environment setup for running Nextflow in sandboxed/offline contexts, including wrapper scripts that invoke Nextflow indirectly.
- Where: `.agents/skills/nextflow/SKILL.md`.
- Coverage: Java runtime pinning, Nextflow cache location, offline mode, and shared Conda cache/env paths for rerun reuse.

## Skill: centrifuge bucketing (Nextflow)

- Scope: read classification, bucketing, and summary tables.
- Entry points: `pipelines/centrifuge_bucketing.nf`, `pipelines/centrifuge_bucketing_all.nf`.
- Where:
  - prelim_analysis: `outs/prelim_analysis/01.bucketing`
  - targeted_analysis: `outs/targeted_analysis/01.bucketing`
- Inputs: `metadata/seq_samples/samples_prelim_analysis.tsv` or `metadata/seq_samples/samples_targeted_analysis.tsv` (normalized `sample_id` + raw `fastq_sample_id`) plus Centrifuge index/taxdump.
- Outputs:
  - prelim_analysis: `outs/prelim_analysis/01.bucketing`, `outs/prelim_analysis/01.bucketing/reports`
  - targeted_analysis: `outs/targeted_analysis/01.bucketing`, `outs/targeted_analysis/01.bucketing/reports`
- MultiQC table prep helper: `scripts/taxonomy_assignment/prepare_centrifuge_multiqc_inputs.py`.

## Skill: mapping vs PAVE (Bowtie2)

- Scope: mapping and rough strain assignment.
- Entry points: `pipelines/bowtie_vs_pave.nf` (config: `config/user.config`).
- Where:
  - prelim_analysis: `outs/prelim_analysis/02.mapping_vs_pave`
  - targeted_analysis: `outs/targeted_analysis/02.mapping_vs_pave`
- Inputs: bucketed FASTQs from the corresponding step 01 output; bucket selection via `params.bucket_tid` in `config/pipelines/bowtie_vs_pave.config`.
- Reference assets: PAVE FASTA/GFF3 under `refdata/pave/`, plus derived BEDs and feature tables under `derived_data/refdata/pave/`.
- Outputs: per-step outputs and `reports/` under the locations above (including strain assignment + coverage table in step 02 reports).
- Step 02 MultiQC focuses on mapping/coverage summaries; `General Statistics`, `Samtools`, and `Bcftools` sections are intentionally omitted.
- MultiQC table prep helper: `scripts/coverage/prepare_bowtie_multiqc_inputs.py`.

## Skill: variant analysis

- Scope: aggregate E6/E7 variants, variant effects, optional lineage SNP comparison, and (targeted only) optional database comparison.
- Entry points: `pipelines/variant_analysis.nf` (config: `config/user.config`).
- Where:
  - prelim_analysis: `outs/prelim_analysis/03.variant_analysis`
  - targeted_analysis: `outs/targeted_analysis/03.variant_analysis`
- Inputs: mapping outputs from step 02 (`outs/*/02.mapping_vs_pave/`) plus PAVE reference assets under `refdata/pave/` and `derived_data/refdata/pave/`.
- Outputs: `reports/` under the locations above (E6/E7 variants, variant effects, lineage SNP comparison, database comparison tables when enabled, MultiQC).
- Variant-analysis MultiQC includes mapping `idxstats` and `bcftools stats` inputs so `General Statistics`, `Samtools`, and `Bcftools` sections are available there (at the bottom of the report).
- MultiQC helpers: `scripts/variants/prepare_variant_multiqc_inputs.py`, `scripts/variants/prepare_database_multiqc_tables.py`, and `scripts/variants/reorder_multiqc_sections.py`.

## Skill: VirStrain reports (optional)

- Scope: VirStrain-based strain reports (prelim_analysis only).
- Entry points: `pipelines/virstrain.nf` (config: `config/user.config`).
- Where: `outs/prelim_analysis/04.virstrain`.
- Inputs: bucketed FASTQs from `outs/prelim_analysis/01.bucketing/`; bucket selection via `params.bucket_tid` in `config/pipelines/virstrain.config`.
- Outputs: `outs/prelim_analysis/04.virstrain`, `outs/prelim_analysis/04.virstrain/reports`.
- MultiQC table prep helper: `scripts/virstrain/prepare_virstrain_multiqc_inputs.py`.

## Skill: phylogenetic trees (HPV16/HPV18)

- Scope: tree generation for HPV16 and HPV18.
- Entry points: `pipelines/phylo_tree.nf` (user config: `config/user.config`; step path config: `config/analyses/targeted_analysis.config` with profiles `targeted_hpv16_tree`, `targeted_hpv18_tree`).
- Where:
  - HPV16: `outs/targeted_analysis/04.hpv16_tree`
  - HPV18: `outs/targeted_analysis/05.hpv18_tree`
- Inputs: curated tree inputs under `derived_data/refdata/hpv16_tree` and `derived_data/refdata/hpv18_tree` (prepared from `refdata/hpv16_tree` and `refdata/hpv18_tree`, plus accession lists in `metadata/hpv16_tree/hpv16_tree_db_selection.txt` and `metadata/hpv18_tree/hpv18_tree_db_selection.txt`).
- Outgroups are listed in `metadata/hpv16_tree/hpv16_tree_outgroups.txt` / `metadata/hpv18_tree/hpv18_tree_outgroups.txt` and extracted from the PAVE FASTA.
- Derived inputs are generated by the pipeline when missing or older than the raw `refdata` inputs.
- Tree visualizations are rendered in circular layout by default, using topology depth (branch lengths ignored unless explicitly enabled), and written to `outs/targeted_analysis/04.hpv16_tree/phylo_tree.svg` and `outs/targeted_analysis/05.hpv18_tree/phylo_tree.svg` (and corresponding PNG files).
- Outputs: alignment/tree artifacts under each step directory, `phylo_tree.svg` / `phylo_tree.png` at step root, and `reports/phylo_tree_summary.multiqc.tsv`. MultiQC reports land under `results/reports/targeted_analysis/`.
- Lineage annotation helpers read `metadata/hpv16_tree/hpv16_lineage_refs.tsv` and `metadata/hpv18_tree/hpv18_lineage_refs.tsv` to assign lineages to tree tips when needed.

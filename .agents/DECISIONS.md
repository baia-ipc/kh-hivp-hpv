# DECISIONS

This log records notable decisions made for this repository.
Format:
- Date (YYYY-MM-DD): Decision
  - Context:
  - Decision:
  - Rationale:
  - Consequences:

## Decisions

- 2026-02-04: Move analysis outputs to `outs/` and track curated results under `results/`
  - Context: analysis outputs and reports were stored under analysis directories, and MultiQC reports lived alongside other reports.
  - Decision: write outputs and non‑MultiQC reports under `outs/<analysis>/<step>/`, store MultiQC reports under `results/multiqc/<analysis>/`, and keep curated results tracked in git under `results/` while ignoring raw analysis outputs.
  - Rationale: separate large run artifacts from tracked outputs and standardize report locations.
  - Consequences: update configs, pipelines, scripts, and documentation; migrate existing outputs into `outs/` and `results/`.

- 2026-02-04: Derive NCBI selection TSVs from metadata accession lists
  - Context: tree selection lists moved out of `refdata/`, and selection TSVs should be derived consistently for HPV16/HPV18.
  - Decision: store accession lists in `metadata/hpv16_tree_db_selection.txt` and `metadata/hpv18_tree_db_selection.txt`, and derive the selection TSVs in the phylo tree pipeline.
  - Rationale: keep user-editable selections in metadata and generate consistent derived inputs.
  - Consequences: add a selection-build script, update phylo tree configs/pipeline, and update documentation references.

- 2026-02-04: Add offline tree visualization + MultiQC tree summary stats
  - Context: tree construction steps relied on step-local READMEs for manual guidance and MultiQC lacked tree previews and intermediate statistics.
  - Decision: move tree reference acquisition instructions to the user manual, remove step README files, and extend the phylo tree pipeline to render offline tree images and emit summary stats for MultiQC.
  - Rationale: keep user-facing instructions centralized and make tree outputs self-contained in the MultiQC report.
  - Consequences: new tree rendering/stats scripts, updated phylo tree pipeline and MultiQC config, and a Biopython dependency in the pipeline env.

- 2026-02-03: Split mapping vs variant analysis steps and align step naming across analyses
  - Context: variant aggregation and database comparison were bundled with mapping in step 02, and prelim_analysis step names differed from targeted_analysis.
  - Decision: keep step 02 as mapping-only (`mapping_vs_pave`), add step 03 `variant_analysis` in both analyses (targeted step 03 also runs database SNP comparison), renumber HPV tree steps to 04/05, and rename prelim_analysis steps to `bucketing` and `mapping_vs_pave`.
  - Rationale: isolate variant analysis and keep step naming consistent across analyses.
  - Consequences: new pipeline `pipelines/variant_analysis.nf`, updated wrappers/configs/docs, and new step outputs under `*/03.variant_analysis`.

- 2026-02-03: Rename intermediate_files to derived_data and consolidate indices
  - Context: intermediate assets mixed derived refdata and reusable indices across analysis outputs.
  - Decision: rename `intermediate_files/` to `derived_data/`, and share the Bowtie/PAVE index under `derived_data/indices/bowtie_vs_pave`.
  - Rationale: clarify that the data are derived and reduce duplicated indices between analyses.
  - Consequences: update configs/docs to use `derived_data/` paths and move HPV16/HPV18 reference FASTAs to `refdata/`.

- 2026-02-03: Derive Nextflow concurrency from wrapper args
  - Context: Nextflow config validation rejects `params.threads` references inside `config/pipelines/*.config` on this system.
  - Decision: remove `params.threads` from pipeline configs and have wrapper scripts pass `-process.maxForks`, `-executor.queueSize`, and `-process.cpus` based on `config/user.config`.
  - Rationale: keep user-level control in `params.threads` without invalid config attributes.
  - Consequences: wrappers must read `threads` from `config/user.config` before running Nextflow.

- 2026-02-03: Add strain assignment + coverage report to step 02
  - Context: needed a per-sample table combining top strains, coverage, and patient metadata.
  - Decision: generate `strain_assignment_coverage.tsv` in step 02 reports by joining top strains, coverage stats, and metadata files.
  - Rationale: consolidate strain assignment, coverage, and clinical context in a single table.
  - Consequences: step 02 reports and MultiQC now include the new table.

- 2026-02-03: Drop prelim_analysis gene-only E6/E7 steps
  - Context: prelim_analysis steps 03/04 duplicated E6/E7 variant extraction already covered by step 02.
  - Decision: remove steps 03/04 and rely on step 02 full-genome mapping with BED-based E6/E7 extraction.
  - Rationale: keep one consistent strategy with targeted_analysis and reduce redundant outputs.
  - Consequences: remove E6/E7 step wrappers/docs/configs; step 02 reports remain the source for E6/E7 variants and coverage summaries.

- 2026-02-03: Move shared indices under intermediate_files
  - Context: bowtie/virstrain indices were stored inside step directories.
  - Decision: relocate step indices to `intermediate_files/indices/` with per-analysis subdirectories.
  - Rationale: centralize reusable indices and keep step outputs focused on run artifacts.
  - Consequences: update configs and documentation to point at shared index locations.

- 2026-02-03: Simplify step numbering
  - Context: step identifiers used 001.0-style labels across directories and docs.
  - Decision: rename step identifiers to two-digit forms (01–05) throughout the repo.
  - Rationale: shorten paths and improve readability.
  - Consequences: update analysis directories, wrappers, configs, and documentation references.

- 2026-02-03: Group scripts by concern
  - Context: scripts were grouped by pipeline names rather than the type of task.
  - Decision: reorganize scripts into taxonomy_assignment, top_strains, coverage, variants, pave, and virstrain subdirectories.
  - Rationale: make script locations reflect their function and improve discoverability.
  - Consequences: update pipeline/script references and documentation paths.

- 2026-02-03: Shorten analysis directory names
  - Context: analysis names were long and repeated across configs, docs, and scripts.
  - Decision: rename the analysis directories and related runner/config references to the shorter names prelim_analysis and targeted_analysis.
  - Rationale: make paths and commands shorter while keeping intent clear.
  - Consequences: update wrappers, configs, metadata sample paths, and documentation references.

- 2026-01-24: Consolidate analyses into prelim_analysis and targeted_analysis
  - Context: analysis-1 and analysis-2 overlapped; analysis-3 needed a stable final name.
  - Decision: merge analysis-1/analysis-2 into prelim_analysis and rename analysis-3 to targeted_analysis.
  - Rationale: simplify layout, reduce duplication
  - Consequences: update references, inventories, and defaults to use prelim_analysis and targeted_analysis.

- 2026-01-24: Centralize configuration and metadata
  - Context: scripts contained hardcoded paths and sample lists.
  - Decision: keep configuration in config/ and hardcoded data in metadata/.
  - Rationale: improve reuse and reduce step-specific edits.
  - Consequences: pipelines/scripts must read config/metadata and avoid inline literals.

- 2026-01-24: Flatten analysis step directories
  - Context: prelim_analysis/ and targeted_analysis/ used a nested steps/ folder.
  - Decision: move step directories directly under prelim_analysis/ and targeted_analysis/.
  - Rationale: simplify paths and reduce redundant nesting.
  - Consequences: update scripts, pipelines, and docs to remove steps/ from paths.

- 2026-01-24: Migrate bowtie vs PAVE mapping to Nextflow
  - Context: step 02 relied on per-step scripts with hardcoded paths.
  - Decision: centralize scripts under `scripts/` and run step 02 via `pipelines/bowtie_vs_pave.nf`.
  - Rationale: reduce duplication and make configuration consistent across analyses.
  - Consequences: use `config/user.config` for user inputs and `config/pipelines/bowtie_vs_pave.config` for fixed bucket selection.

- 2026-01-24: Migrate VirStrain reports to Nextflow
  - Context: step 05 used step-local scripts and hardcoded reference paths.
  - Decision: centralize scripts under `scripts/` and run step 05 via `pipelines/virstrain.nf`.
  - Rationale: align with the shared pipeline layout and remove hardcoded paths.
  - Consequences: use `config/user.config` for user inputs and `config/pipelines/virstrain.config` for fixed bucket selection.

- 2026-01-24: Migrate E6 mapping to Nextflow
  - Context: step 03 relied on step-local scripts and per-step index creation.
  - Decision: move shared scripts to `scripts/` and run E6 mapping via `pipelines/pave_gene_mapping.nf`.
  - Rationale: standardize mapping steps and remove hardcoded references.
  - Consequences: use `config/analyses/prelim_analysis.config` (profile `preliminary_pave_e6`) and shared metadata for bucket selection.

- 2026-01-24: Migrate E7 mapping to Nextflow
  - Context: step 04 relied on the same step-local scripts as E6.
  - Decision: use the shared `pipelines/pave_gene_mapping.nf` pipeline with a dedicated config.
  - Rationale: keep the E6/E7 analyses consistent and reduce duplication.
  - Consequences: use `config/analyses/prelim_analysis.config` (profile `preliminary_pave_e7`) and shared metadata for bucket selection.

- 2026-01-24: Migrate HPV16 tree build to Nextflow
  - Context: step 03 relied on multiple per-step scripts for alignment and tree building.
  - Decision: centralize the tree build as `pipelines/phylo_tree.nf` with step config.
  - Rationale: standardize tree workflows and reduce step-local scripts.
  - Consequences: use `config/user.config` and `metadata/hpv16_tree_outgroups.txt`.

- 2026-01-24: Migrate HPV18 tree build to Nextflow
  - Context: step 04 mirrored the HPV16 tree workflow with separate scripts.
  - Decision: use the shared `pipelines/phylo_tree.nf` pipeline with an HPV18 config.
  - Rationale: keep HPV16/HPV18 tree generation consistent and centralized.
  - Consequences: use `config/user.config` and `metadata/hpv18_tree_outgroups.txt`.

- 2026-01-24: Add reference snapshot directory
  - Context: need to compare old results vs updated pipelines.
  - Decision: store a copy of outputs/reports/indexes under `reference-results/` and ignore it in git.
  - Rationale: enable regression checks without altering tracked outputs.
  - Consequences: refresh the snapshot when results change.

- 2026-01-27: Cap Nextflow concurrency by default
  - Context: running many tasks at once can overload shared nodes.
  - Decision: set `process.maxForks = 24` and `executor.queueSize = 24` in step config files under `config/`.
  - Rationale: keep default runs bounded while still parallel.
  - Consequences: adjust the cap in config files when running on larger systems.

- 2026-01-27: Use metadata sample IDs for multi-sample bucketing
  - Context: legacy centrifuge outputs are named after the sample IDs listed in metadata, not the normalized FASTQ filenames.
  - Decision: set the sample ID in `pipelines/centrifuge_bucketing_all.nf` from the metadata sample column.
  - Rationale: keep `--skip-align` compatible with precomputed alignment/report files and historical naming.
  - Consequences: alignment/report filenames follow metadata sample IDs for multi-sample runs.

- 2026-02-02: Centralize Conda environment definitions under pipelines
  - Context: pipeline env files were mixed with other config in `config/`.
  - Decision: move all `*.env.yml` to `pipelines/conda_env/` and update references.
  - Rationale: keep pipeline runtime environments alongside the workflows that consume them.
  - Consequences: configs and docs must reference `pipelines/conda_env/*` for Conda envs.

- 2026-02-02: Split user vs technical Nextflow configuration
  - Context: pipeline configs mixed user-editable parameters with executor/conda wiring, and step paths lived in wrappers.
  - Decision: keep user-editable configs in `config/`, move technical Nextflow settings to `config/pipelines/`, and add step-specific config files for inputs/outputs.
  - Rationale: ensure users only edit `config/` while keeping technical defaults centralized.
  - Consequences: wrappers pass multiple `-c` files; new step configs define `outdir`, `reports_dir`, and inputs.

- 2026-02-02: Relocate MultiQC configs alongside pipelines
  - Context: MultiQC configs were mixed into `config/` with user-editable settings.
  - Decision: move `*.multiqc.yml` into `pipelines/multiqc/` and update references.
  - Rationale: keep pipeline-owned config with pipeline assets while leaving `config/` for user edits.
  - Consequences: technical configs and pipelines reference `pipelines/multiqc/*`.

- 2026-02-02: Derive PAVE BED intervals from GFF3
  - Context: multiple pipelines require BED intervals for E6/E7 SNP extraction.
  - Decision: treat BED files as derived data under `intermediate_files/refdata/pave/bed`, generated via `scripts/pave/gff3_to_bed.run_all.sh`.
  - Rationale: BEDs are derived from GFF3s and should not live under raw reference inputs.
  - Consequences: technical configs reference the derived BED directory.

- 2026-02-02: Consolidate user config into `config/user.config`
  - Context: user parameters were split across multiple `config/*.config` files.
  - Decision: move all user-editable parameters into a single `config/user.config`.
  - Rationale: keep user configuration in one place and set shared defaults (e.g., `threads`) only once.
  - Consequences: wrappers and docs reference `config/user.config`; per-pipeline user configs are removed.

- 2026-02-02: Move step wrapper scripts into `bin/`
  - Context: step runner scripts lived under each analysis step directory.
  - Decision: relocate wrappers into a top-level `bin/` directory and add analysis-level runners.
  - Rationale: keep execution entry points centralized and remove step-local `scripts/`.
  - Consequences: update docs and references to use `bin/*.run*.sh`.

- 2026-02-02: Move step path configs into `bin/config`
  - Context: step-specific configs only contained fixed input/output paths and were not user-editable.
  - Decision: relocate path-only configs under `bin/config` and keep user-editable configs in `config/`.
  - Rationale: separate internal path wiring from user-facing configuration.
  - Consequences: update wrapper scripts and docs to point at `config/analyses/*`.

- 2026-02-02: Rename runners and isolate single-sample wrappers
  - Context: step wrappers used `run_all.sh` vs `run.sh` naming and lived in a single directory.
  - Decision: rename all-step wrappers to `run.sh`, rename single-sample wrappers to `run_sample.sh`, and move them under `bin/*steps/single_sample/`.
  - Rationale: make the default entry point consistent and keep per-sample utilities separate.
  - Consequences: update documentation and runner references to new paths.

- 2026-02-02: Move derived refdata paths into technical configs
  - Context: derived reference paths were defined in user-editable configs.
  - Decision: relocate derived refdata path parameters into `config/pipelines/*.config`.
  - Rationale: keep user configs focused on tunable inputs and avoid editing fixed internal paths.
  - Consequences: update pipelines and wrappers to read derived paths from technical configs.

- 2026-02-03: Group scripts into concern-based subdirectories
  - Context: the scripts directory had a flat list that was hard to scan and maintain.
  - Decision: organize scripts into subdirectories that match the sections in `docs/SCRIPTS.md`.
  - Rationale: improve discoverability and keep documentation and paths aligned.
  - Consequences: update all references to scripts with the new subdirectory paths.

- 2026-02-03: Rename the Cambodia SNP pipeline to database_snps
  - Context: the targeted SNP comparison pipeline was named after a specific country.
  - Decision: rename `pipelines/cambodia_snps.nf` to `pipelines/database_snps.nf`, along with its configs and outputs, and update variable names to use database/target-country terminology.
  - Rationale: keep the workflow reusable for other target countries without changing names.
  - Consequences: update pipeline, configs, MultiQC config, and docs to reflect the new naming.

- 2026-02-03: Rename input directory to input_reads
  - Context: raw FASTQ inputs were stored under a generic `input/` directory.
  - Decision: rename the top-level directory to `input_reads/` and update references in metadata and documentation.
  - Rationale: clarify that the directory contains raw reads.
  - Consequences: update sample sheets and docs to use `input_reads/`.

- 2026-02-03: Move database SNP outputs under step 03 reports/output
  - Context: database SNP comparison outputs lived under `targeted_analysis/03.variant_analysis/database_snps/`, which looked detached from step 03 reports.
  - Decision: place database SNP outputs under `targeted_analysis/03.variant_analysis/output/database_snps` and `targeted_analysis/03.variant_analysis/reports/database_snps`.
  - Rationale: keep all step 03 outputs visible under the step’s output/report structure.
  - Consequences: update configs and docs to the new paths.

- 2026-02-03: Consolidate targeted step 03 MultiQC report
  - Context: database comparison produced a second MultiQC report under a subdirectory.
  - Decision: keep a single MultiQC report in `targeted_analysis/03.variant_analysis/reports/` and consolidate database tables into that reports directory.
  - Rationale: reduce confusion by keeping one report per step.
  - Consequences: add a combined MultiQC config and consolidate database report tables into the step 03 reports directory.

- 2026-02-03: Merge database comparison into variant analysis pipeline
  - Context: targeted step 03 ran a separate database SNP pipeline after variant analysis.
  - Decision: fold database comparison into `pipelines/variant_analysis.nf` behind `include_database`, enabled by default in the targeted profile and disabled in prelim.
  - Rationale: simplify step 03 execution and keep all outputs within a single pipeline run.
  - Consequences: remove `pipelines/database_snps.nf` and its config, update wrappers/docs, and extend `variant_analysis` config and workflow.

- 2026-02-03: Make phylogenetic tree inputs fully derived
  - Context: tree preparation required manual commands and checked derived inputs into git.
  - Decision: move curated selection lists into `refdata/`, generate all derived tree inputs in `pipelines/phylo_tree.nf`, and ignore `derived_data/` in git.
  - Rationale: eliminate manual steps and keep derived assets out of version control.
  - Consequences: update phylo tree configs, scripts, and documentation; remove tracked `derived_data/` contents.

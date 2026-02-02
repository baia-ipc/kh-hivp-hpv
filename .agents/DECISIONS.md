# DECISIONS

This log records notable decisions made for this repository.
Format:
- Date (YYYY-MM-DD): Decision
  - Context:
  - Decision:
  - Rationale:
  - Consequences:

## Decisions

- 2026-01-24: Consolidate analyses into analysis-input1 and analysis-input2
  - Context: analysis-1 and analysis-2 overlapped; analysis-3 needed a stable final name.
  - Decision: merge analysis-1/analysis-2 into analysis-input1 and rename analysis-3 to analysis-input2.
  - Rationale: simplify layout, reduce duplication, and align with .agents/GOALS.md.
  - Consequences: update references, inventories, and defaults to use analysis-input1/2.

- 2026-01-24: Centralize configuration and metadata
  - Context: scripts contained hardcoded paths and sample lists.
  - Decision: keep configuration in config/ and hardcoded data in metadata/.
  - Rationale: improve reuse and reduce step-specific edits.
  - Consequences: pipelines/scripts must read config/metadata and avoid inline literals.

- 2026-01-24: Flatten analysis step directories
  - Context: analysis-input1/ and analysis-input2/ used a nested steps/ folder.
  - Decision: move step directories directly under analysis-input1/ and analysis-input2/.
  - Rationale: simplify paths and reduce redundant nesting.
  - Consequences: update scripts, pipelines, and docs to remove steps/ from paths.

- 2026-01-24: Migrate bowtie vs PAVE mapping to Nextflow
  - Context: step 002 relied on per-step scripts with hardcoded paths.
  - Decision: centralize scripts under `scripts/` and run step 002 via `pipelines/bowtie_vs_pave.nf`.
  - Rationale: reduce duplication and make configuration consistent across analyses.
  - Consequences: use `config/bowtie_vs_pave.config` and `config/pave_bucket_tid.txt` for inputs.

- 2026-01-24: Migrate VirStrain reports to Nextflow
  - Context: step 003 used step-local scripts and hardcoded reference paths.
  - Decision: centralize scripts under `scripts/` and run step 003 via `pipelines/virstrain.nf`.
  - Rationale: align with the shared pipeline layout and remove hardcoded paths.
  - Consequences: use `config/virstrain.config` and `config/pave_bucket_tid.txt` for inputs.

- 2026-01-24: Migrate E6 mapping to Nextflow
  - Context: step 004 relied on step-local scripts and per-step index creation.
  - Decision: move shared scripts to `scripts/` and run E6 mapping via `pipelines/pave_gene_mapping.nf`.
  - Rationale: standardize mapping steps and remove hardcoded references.
  - Consequences: use `config/pave_e6.config` and shared metadata for bucket selection.

- 2026-01-24: Migrate E7 mapping to Nextflow
  - Context: step 005 relied on the same step-local scripts as E6.
  - Decision: use the shared `pipelines/pave_gene_mapping.nf` pipeline with a dedicated config.
  - Rationale: keep the E6/E7 analyses consistent and reduce duplication.
  - Consequences: use `config/pave_e7.config` and shared metadata for bucket selection.

- 2026-01-24: Migrate HPV16 tree build to Nextflow
  - Context: step 003 relied on multiple per-step scripts for alignment and tree building.
  - Decision: centralize the tree build as `pipelines/phylo_tree.nf` with step config.
  - Rationale: standardize tree workflows and reduce step-local scripts.
  - Consequences: use `config/hpv16_tree.config` and `metadata/hpv16_tree_outgroups.txt`.

- 2026-01-24: Migrate HPV18 tree build to Nextflow
  - Context: step 004 mirrored the HPV16 tree workflow with separate scripts.
  - Decision: use the shared `pipelines/phylo_tree.nf` pipeline with an HPV18 config.
  - Rationale: keep HPV16/HPV18 tree generation consistent and centralized.
  - Consequences: use `config/hpv18_tree.config` and `metadata/hpv18_tree_outgroups.txt`.

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
  - Decision: keep user-editable configs in `config/`, move technical Nextflow settings to `pipelines/config/`, and add step-specific config files for inputs/outputs.
  - Rationale: ensure users only edit `config/` while keeping technical defaults centralized.
  - Consequences: wrappers pass multiple `-c` files; new step configs define `outdir`, `reports_dir`, and inputs.

- 2026-02-02: Relocate MultiQC configs alongside pipelines
  - Context: MultiQC configs were mixed into `config/` with user-editable settings.
  - Decision: move `*.multiqc.yml` into `pipelines/multiqc/` and update references.
  - Rationale: keep pipeline-owned config with pipeline assets while leaving `config/` for user edits.
  - Consequences: technical configs and pipelines reference `pipelines/multiqc/*`.

- 2026-02-02: Move step wrapper scripts into `bin/`
  - Context: step runner scripts lived under each analysis step directory.
  - Decision: relocate wrappers into a top-level `bin/` directory and add analysis-level runners.
  - Rationale: keep execution entry points centralized and remove step-local `scripts/`.
  - Consequences: update docs and references to use `bin/*.run*.sh`.

- 2026-02-02: Move step path configs into `bin/config`
  - Context: step-specific configs only contained fixed input/output paths and were not user-editable.
  - Decision: relocate path-only configs under `bin/config` and keep user-editable configs in `config/`.
  - Rationale: separate internal path wiring from user-facing configuration.
  - Consequences: update wrapper scripts and docs to point at `bin/config/*`.

- 2026-02-02: Rename runners and isolate single-sample wrappers
  - Context: step wrappers used `run_all.sh` vs `run.sh` naming and lived in a single directory.
  - Decision: rename all-step wrappers to `run.sh`, rename single-sample wrappers to `run_sample.sh`, and move them under `bin/sample/`.
  - Rationale: make the default entry point consistent and keep per-sample utilities separate.
  - Consequences: update documentation and runner references to new paths.

- 2026-02-02: Move derived refdata paths into technical configs
  - Context: derived reference paths were defined in user-editable configs.
  - Decision: relocate derived refdata path parameters into `pipelines/config/*.technical.config`.
  - Rationale: keep user configs focused on tunable inputs and avoid editing fixed internal paths.
  - Consequences: update pipelines and wrappers to read derived paths from technical configs.

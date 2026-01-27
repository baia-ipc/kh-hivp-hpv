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
  - Rationale: simplify layout, reduce duplication, and align with GOALS.md.
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
  - Consequences: use `config/bowtie_vs_pave.config` and `metadata/pave_bucket_tid.txt` for inputs.

- 2026-01-24: Migrate VirStrain reports to Nextflow
  - Context: step 003 used step-local scripts and hardcoded reference paths.
  - Decision: centralize scripts under `scripts/` and run step 003 via `pipelines/virstrain.nf`.
  - Rationale: align with the shared pipeline layout and remove hardcoded paths.
  - Consequences: use `config/virstrain.config` and `metadata/pave_bucket_tid.txt` for inputs.

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

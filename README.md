# Kh_HIVp_HPV

This repository contains a reproducible workflow used for HPV sequencing analysis.

## Analyses

Two analyses are included:

- `prelim_analysis/`: analysis of the first three MiSeq runs (all patients + controls).
- `targeted_analysis/`: deeper sequencing for HPV16/HPV18‑positive samples.

To run the analyses:

- place or link input reads under `input_reads/`
- place reference inputs under `refdata/`
- ensure Nextflow and Conda are installed
- run the wrappers in `bin/` (all steps or step-by-step)

Wrapper entry points:

- `bin/prelim_analysis.run.sh`
- `bin/targeted_analysis.run.sh`

A detailed user manual is available under `docs/USER_MANUAL.md`.

Each analysis consists of multiple steps (01, 02, …). Each step stores outputs
and reports under its own step directory (`output/` and `reports/`).

## Repository content

[1] Executable code
- `bin`: user-level scripts (run analyses or individual steps)
- `pipelines`: Nextflow pipelines called by the wrappers
- `pipelines/conda_env`: Conda environments used by the pipelines
- `pipelines/multiqc`: MultiQC configuration files
- `scripts`: Python and shell utilities used by the pipelines

[2] Configuration
- `config`: user-editable configuration (`user.config`) and technical configs
- `config/bin`: step path config profiles used by wrappers
- `config/pipelines`: technical Nextflow configuration
- `metadata`: taxonomy bins, sample lists, and reference metadata

[3] Input
- `input_reads`: input Illumina readsets (linked or copied)
- `refdata`: reference data (PAVE, lineage references, NCBI downloads)
- `testdata`: small datasets used by tests

[4] Output
- `prelim_analysis/`: outputs and reports for the preliminary analysis
- `targeted_analysis/`: outputs and reports for the targeted analysis
- `intermediate_files/`: derived reference assets and shared indices
  - `intermediate_files/refdata`: derived reference assets (BED/TSV/tree inputs)
  - `intermediate_files/indices`: shared Bowtie/VirStrain indices

[5] Documentation
- `docs`: user manual and technical documentation

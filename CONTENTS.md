# High level summary of the contents of the repository

- analyses:
  - outputs live under `outs/` by analysis/step (not tracked in git)
  - curated, tracked outputs live under `results/`
  - most of the code is in `scripts/` and `pipelines/`; step runners live in `bin/`

- `pipelines/`: Nextflow workflows and wrapper assets
  - `conda_env/`: Conda environment definitions
  - `multiqc/`: MultiQC configuration files used by pipelines

- `scripts/`: reusable utilities grouped by concern
  (taxonomy_assignment, top_strains, coverage, variants, pave, virstrain, phylo_tree)

- `bin/`: step and analysis runner scripts (wrappers around Nextflow pipelines)
  - `prelim_analysis.steps/`: per-step wrappers (plus `single_sample/`)
  - `targeted_analysis.steps/`: per-step wrappers (plus `single_sample/`)
  - `run_step.py`: generic step runner used by per-step wrappers

- `input_reads/`: symlinks to external raw data locations (not stored in-repo)

- `metadata/`: curated metadata inputs
  - `bucketing/`
  - `cohort/`
  - `hpv16_tree/`
  - `hpv18_tree/`
  - `seq_samples/`

- `config/`: user-editable configuration files
  - `analyses/`: step path config profiles used by wrappers
  - `pipelines/`: technical Nextflow config shared by pipelines
  - `steps/`: JSON configs for the generic step runner

- `refdata/`: external reference inputs (PAVE FASTA/GFF3, NCBI downloads)

- `derived_data/`: generated intermediate assets
  - `refdata/`: processed reference assets (feature tables, BED intervals, curated tree inputs)
  - `indices/`: shared indices (Bowtie/PAVE + VirStrain)

- `outs/`: analysis outputs and non‑MultiQC reports (ignored in git)

- `results/`: curated copies of key outputs (selected reports and reference results)

- `docs/`: documentation (user manual, developer docs, and notes)
  - `developers/`: developer manual, scripts reference, and step docs
  - `notes/`: analysis notes and methods writeups

- `.agents/`: agent-oriented docs and instructions (OPERATIONS, WORKFLOWS, etc.)

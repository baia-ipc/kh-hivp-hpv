# Terminology:

- an "analysis" is a collection of single analysis steps
- each step is a numbered wrapper script, which calls a generic Nextflow
  pipeline with an analysis-specific step configuration
- the pipelines are written for a given concern (e.g. variant calling)
  to be used in different analyses

# High level summary of the contents of the repository

## Code

- `pipelines/`: Nextflow workflows and wrapper assets
  - `conda_env/`: Conda environment definitions
  - `multiqc/`: MultiQC configuration files used by pipelines

- `scripts/`: helper Python and shell scripts, grouped in subdirectories
   by concern (taxonomy\_assignment, top\_strains, coverage, variants,
   pave, virstrain, phylo\_tree, steps)

- `bin/`: analysis runner scripts (wrappers around Nextflow pipelines)
  - `prelim_analysis.run.sh`: preliminary analysis wrapper
  - `prelim_analysis.steps/*.sh`: per-step wrappers
  - `targeted_analysis.run.sh`: targeted analysis wrapper
  - `targeted_analysis.steps/*.sh`: per-step wrappers

## Input and configuration

- `input_reads/`: put here the symlinks to external raw data locations
                  (not stored in-repo)

- `config/`: configuration files
  - `user.config`: user configuration file for paths and parameters
  - `analyses/`: configuration for the analysis wrappers
  - `steps/`: configuration of the single steps of the analyses
  - `pipelines/`: configuration of the Nextflow workflows

- `metadata/`: curated metadata files, divided by concern
               (bucketing, cohort, phylogenetic tree inputs, sample lists)

- `refdata/`: external reference inputs (PAVE FASTA/GFF3, NCBI sequences and metadata)

## Output

(not stored in git repo; organization explained here for clarity)

- `derived_data/`: generated intermediate assets
  - `refdata/`: processed reference assets
  - `indices/`: shared indices (e.g. Bowtie indices)

- `outs/`: all analysis outputs, divided by step

- `results/`: curated copies of key outputs (selected reports and reference results)

## Documentation

- `docs/`: user and developer documentation
  - `CONTENTS.md`: this file
  - `USER_MANUAL.md`: user manual and step-by-step instructions
  - `developers/`: developer manual, scripts reference, and step docs

- `.agents/`: coding agents-oriented documentation and skills
  - `PROJECT.md`: compact project facts/current state for agents
  - `WORKFLOW.md`: stable analysis step order/dependencies
  - `skills/`: local reusable skill specifications for recurring agent tasks

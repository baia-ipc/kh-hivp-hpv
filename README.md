# Kh_HIVp_HPV

This repository contains a reproducible workflow that we used for
the analysis of HPV sequencing data in our study.

## Analyses

Two sets of analyses are contained. The first (`prelim_analysis`) contains an analysis of
all 64 patients (and some controls), based on the first 3 Miseq runs. After that, we followed with an deeper sequencing
analysis of the patients for which the first analysis and the GenExpert results indicated infection with HPV16 and
HPV18 (`targeted_analysis`).

To run the analysis:
- the input readsets must be copied or linked into the `input` directory
- appropriate reference data must be copied or linked into the `refdata` directory
- Nextflow and Conda must be installed on the system
- the scripts `bin/prelim_analysis.run.sh` and/or
  `bin/targeted_analysis.run.sh` must be run

A detailed user manual is available under `docs/USER_MANUAL.md`.
The results of the analysis will be stored under directories named after the analysis title.
Each analysis consists of multiple steps, numbered sequentially from 001. The results
of each step are stored independently in directories for each step (e.g. `001.*`) into
subdirectories called `output` and `reports`.

## Repository content

The repository has the following structure:

[1] Executable code
- `bin`: user-level scripts, wrappers to run the pipelines for the first and second analysis
         (complete analysis or step-by-step)
- `pipelines`: Nextflow pipelines called by the wrapper under `bin`
- `pipelines/conda_env`: Conda environments used by the Nextflow pipelines
- `pipelines/multiqc`: Configuration files for the MultiQC reports created by the pipelines
- `scripts`: Python and shell scripts used by the Nextflow pipelines

[2] Configuration
- `config`: configuration files for the pipeline, including a `user.config` file
            and directories with technical configuration files for the wrapper scripts (`bin`)
            and the Nextflow pipelines (`pipelines`) which are typically not edited by the user
- `metadata`: metadata files, provided with the repository, e.g. taxonomy bins,
              Genbank accessions of reference data to include in the trees etc

[3] Input
- `input`: directories containing the input Illumina readsets
- `refdata`: reference data, such as HPV sequences and annotations and lineage reference
             sequences from PAVE database, database sequences from Genbank, etc
- `testdata`: mini-datasets consisting of just a few reads, used by tests

[4] Output
- `prelim_analysis/`: analysis for the first input dataset (all patients)
- `targeted_analysis/`: analysis for the second input dataset (HPV16/18-focused)
- `intermediate_files`: intermediate files, e.g. indices or format conversions from the reference results

[5] Documentation
- `docs`: user manual and technical documentation of the pipelines and scripts

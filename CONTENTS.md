# High level summary of the contents of the repository

- analysis-input\*/ workflows used for the analyses; in total 2 analyses were done
  - analysis of the first three batches of sequences (Miseq): analysis-input1/
  - analysis of the subsequent sequencing, focused on HPV16/HPV18 samples:
    analysis-input2/

- analysis-input\*/\*:
  - each analysis directory contain subdirectories for each step, numbered
    according to the order in which they were run (01, 02, etc)
  - each step subdirectory contains separate subdirectories for scripts, output
    files and reports and in some cases for config files, metadata files, input
    and reference data
  - most of the code is contained in the scripts and pipelines in the root-level
    directories described below, the step-level scripts are mostly wrappers to call

- pipelines/ wrapper scripts and Nextflow workflows
  - conda_env/ per-pipeline Conda environment definitions
  - config/ technical Nextflow config shared by pipelines
  - multiqc/ MultiQC configuration files used by pipelines

- scripts/ reusable Python scripts for single operations such as
           LCA computing, bucketing, FASTQ splitting, and strain summaries

- input/ symlinks to external raw data locations (not stored in-repo)

- metadata/ taxonomy bucket definitions and sample lists

- config/ user-editable configuration files

- refdata/ reference data split into:
  - raw/ external inputs (PAVE FASTA/GFF3, NCBI downloads)
  - derived/ processed reference assets (feature tables, curated tree inputs)

- docs/ technical documentation for the analysis steps (human-readable)

- .agents/ agent-oriented docs and instructions (GOALS, OPERATIONS, WORKFLOWS, etc.)

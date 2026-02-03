# High level summary of the contents of the repository

- preliminary-analysis-all-patients/ and targeted-analysis-hpv16-hpv18/ workflows used for the analyses; in total 2 analyses were done
  - analysis of the first three batches of sequences (Miseq): preliminary-analysis-all-patients/
  - analysis of the subsequent sequencing, focused on HPV16/HPV18 samples:
    targeted-analysis-hpv16-hpv18/

- analysis directories:
  - each analysis directory contain subdirectories for each step, numbered
    according to the order in which they were run (01, 02, etc)
  - each step subdirectory contains outputs and reports and in some cases
    step-specific inputs or reference material
  - most of the code is contained in the scripts and pipelines in the root-level
    directories described below; step runners live in `bin/`

- pipelines/ wrapper scripts and Nextflow workflows
  - conda_env/ Conda environment definitions
  - multiqc/ MultiQC configuration files used by pipelines

- scripts/ reusable Python scripts for single operations such as
           LCA computing, bucketing, FASTQ splitting, and strain summaries

- bin/ step and analysis runner scripts (wrappers around Nextflow pipelines)
  - preliminary-analysis-all-patients.steps/ per-step wrappers (plus single_sample/)
  - targeted-analysis-hpv16-hpv18.steps/ per-step wrappers (plus single_sample/)
  - config/ step path config profiles (internal defaults; not typically edited by users)

- input/ symlinks to external raw data locations (not stored in-repo)

- metadata/ taxonomy bucket definitions and sample lists

- config/ user-editable configuration files
  - bin/ step path config profiles used by wrappers
  - pipelines/ technical Nextflow config shared by pipelines

- refdata/ external reference inputs (PAVE FASTA/GFF3, NCBI downloads)

- intermediate_files/ generated intermediate assets
  - refdata/ processed reference assets (feature tables, BED intervals, curated tree inputs)
  - indices/ bowtie/virstrain indices

- docs/ technical documentation for the analysis steps (human-readable)

- .agents/ agent-oriented docs and instructions (GOALS, OPERATIONS, WORKFLOWS, etc.)

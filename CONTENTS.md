# High level summary of the contents of the repository

- analysis-input\*/ workflows used for the analyses; in total 2 analyses were done
  - analysis of the first three batches of sequences (Miseq): analysis-input1/
  - analysis of the subsequent sequencing, focused on HPV16/HPV18 samples:
    analysis-input2/

- analysis-input\*/\*:
  - each analysis directory contain subdirectories for each step
  - each step subdirectory contains separate subdirectories for scripts, output
    files and reports and in some cases for config files, metadata files, input
    and reference data
  - most of the code is contained in the scripts and pipelines in the root-level
    directories described below, the step-level scripts are mostly wrappers to call

features\_tsv/ collection of HPV reference feature coordinate tables for all human HPV strains

input/ symlinks to external raw data locations (not stored in-repo)

metadata/ taxonomy bucket definitions and sample lists

config/ pipeline and other configuration files

refdata/ curated reference FASTA files used for indices

pipelines/ wrapper scripts and workflows

scripts/ reusable Python scripts for LCA, bucketing, FASTQ splitting, and strain summaries

reference-results/ snapshot of outputs, reports, and indexes for regression comparisons

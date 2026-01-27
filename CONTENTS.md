
Contents of the repository:

analysis-\*/ workflows used for the analyses; in total 2 analyses were done

analysis of the first data (Miseq):

analysis-input1/ merged analysis of the first data; step directories live directly under this folder

analysis of the new data, obtained with an updated wet-lab protocol and focused only to some samples:

analysis-input2/ bucketing reports, bowtie‑vs‑PAVE mapping, and HPV16/HPV18 tree steps; step directories live directly under this folder

features\_tsv/ collection of HPV reference feature coordinate tables for all human HPV strains

input/ symlinks to external raw data locations (not stored in-repo)

metadata/ taxonomy bucket definitions and sample lists

config/ pipeline and other configuration files

refdata/ curated reference FASTA files used for indices

pipelines/ wrapper scripts and workflows

scripts/ reusable Python scripts for LCA, bucketing, FASTQ splitting, and strain summaries

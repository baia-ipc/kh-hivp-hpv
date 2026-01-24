
Contents of the repository:

analysis-\*/ workflows used for the analyses; in total 3 analyses were done

analysis of the first data (Miseq):

analysis-1/ centrifuge + LCA bucketing, bowtie vs PAVE rough strain assignment,
            and VirStrain reports
analysis-2/ similar to analysis‑1, plus separate E6/E7 bowtie-vs‑PAVE steps

analysis of the new data, obtained with an updated wet-lab protocol and focused only to some samples:

analysis-3/ bucketing reports, bowtie‑vs‑PAVE mapping, and HPV16/HPV18 tree steps

features\_tsv/ collection of HPV reference feature coordinate tables for all human HPV strains

input/ symlinks to external raw data locations (not stored in-repo)

metadata/ taxonomy bucket definitions and sample lists

config/ pipeline and other configuration files

pipelines/ wrapper scripts and workflows

scripts/ reusable Python scripts for LCA, bucketing, FASTQ splitting, and strain summaries

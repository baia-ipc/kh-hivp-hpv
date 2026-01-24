
Contents of the repository:

analysis-\*/ workflows used for the analyses; in total 3 analyses were done

analysis of the first data (Miseq):

analysis-1/ centrifuge + LCA bucketing, bowtie vs PAVE rough strain assignment,
            and VirStrain reports (001.0.centrifuge, 002.0.bowtie_vs_pave, 003.0.virstrain)
analysis-2/ similar to analysis‑1, plus separate E6/E7 bowtie-vs‑PAVE steps
            (003.0.bowtie_vs_pave.E6, 004.0.bowtie_vs_pave.E7)

analysis of the new data, obtained with an updated wet-lab protocol and focused only to some samples:

analysis-3/ bucketing reports, bowtie‑vs‑PAVE mapping, and HPV16/HPV18 tree steps
            (001.0.bucketing, 002.0.mapping_vs_pave, 003.0.hpv16_tree, 004.0.hpv18_tree)

features\_tsv/ collection of HPV reference feature coordinate tables for all human HPV strains (e.g., HPV16REF.tsv)

input/ symlinks to external raw data locations (not stored in-repo):
   /srv/vireak/HPV\_11092024 --> analysis-3
   /storage/virology/janin/rawdata/hpv\_miseq --> analysis-1 and analysis-2

metadata/ taxonomy bucket definitions and sample lists (bucket\_taxonomy\_ids.tsv, samples-input1.tsv)

config/ pipeline and other configuration files (centrifuge_bucketing.config, centrifuge_bucketing.env.yml)

pipelines/ wrapper scripts and workflows (centrifuge_bucketing.sh, centrifuge_bucketing.nf, centrifuge_bucketing_all.nf)

scripts/ reusable Python scripts for LCA, bucketing, FASTQ splitting, and strain summaries
  (compute_lca.py, assign_to_buckets.py, bucketize_fastq.py, aggregate_bucket_counts.py, identify_top_strains.py)

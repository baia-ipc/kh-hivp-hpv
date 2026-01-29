# Method

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/phylo_tree.nf`
- Config: `config/hpv18_tree.config`
- Outgroups: `metadata/hpv18_tree_outgroups.txt`
- Inputs: `refdata/hpv18_tree`

Wrappers:

- `run_all.sh` runs the tree pipeline for prepared inputs.
- `run.sh` runs the tree pipeline for prepared inputs.

Outputs:

- Alignment, trimming, and IQ-TREE artifacts under `output/`.
- MultiQC report under `output/reports/multiqc_report.html`.

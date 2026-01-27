# Method

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/phylo_tree.nf`
- Config: `config/hpv16_tree.config`
- Outgroups: `metadata/hpv16_tree_outgroups.txt`

Wrappers:

- `run_all.sh` runs the tree pipeline for prepared inputs.
- `run.sh` runs the tree pipeline for prepared inputs.

Outputs:

- Alignment, trimming, and IQ-TREE artifacts under `output/`.
- MultiQC report under `output/reports/multiqc/multiqc_report.html`.

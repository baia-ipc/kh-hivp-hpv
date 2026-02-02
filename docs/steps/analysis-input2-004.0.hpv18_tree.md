# analysis-input2 step 004: HPV18 phylogenetic tree

## Overview

This step builds an HPV18 phylogenetic tree from prepared sequence inputs
(references + selected outgroups + sample consensus sequences).

## Implementation

- Pipeline: `pipelines/phylo_tree.nf`
- Config: `config/hpv18_tree.config`
- Inputs directory: `refdata/derived/hpv18_tree`
- Outgroup list: `metadata/hpv18_tree_outgroups.txt`

Wrappers:

- `analysis-input2/004.0.hpv18_tree/scripts/run.sh`
- `analysis-input2/004.0.hpv18_tree/scripts/run_all.sh`

## Inputs

Inputs are expected under `refdata/derived/hpv18_tree/` and are prepared from
raw inputs under `refdata/raw/hpv18_tree/` using scripts documented in the
repository root `README.md`.

Sample IDs are derived automatically by `scripts/hpv18_prepare_samples.sh` from
`analysis-input2/002.0.mapping_vs_pave/reports/strains.tsv`, selecting samples
whose top strain is HPV18 for the configured run ID.

## Outputs

- Tree outputs and intermediate artifacts under `output/`
- MultiQC report: `output/reports/multiqc_report.html`

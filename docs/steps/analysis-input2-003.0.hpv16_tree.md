# analysis-input2 step 003: HPV16 phylogenetic tree

## Overview

This step builds an HPV16 phylogenetic tree from prepared sequence inputs
(references + selected outgroups + sample consensus sequences).

## Implementation

- Pipeline: `pipelines/phylo_tree.nf`
- Config: `config/hpv16_tree.config`
- Inputs directory: `refdata/derived/hpv16_tree`
- Outgroup list: `metadata/hpv16_tree_outgroups.txt`

Wrappers:

- `analysis-input2/003.0.hpv16_tree/scripts/run.sh`
- `analysis-input2/003.0.hpv16_tree/scripts/run_all.sh`

## Inputs

Inputs are expected under `refdata/derived/hpv16_tree/` and are prepared from
raw inputs under `refdata/raw/hpv16_tree/` using scripts documented in the
repository root `README.md`.

## Outputs

- Tree outputs and intermediate artifacts under `output/`
- MultiQC report: `output/reports/multiqc_report.html`

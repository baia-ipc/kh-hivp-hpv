# targeted-analysis-hpv16-hpv18 step 003: HPV16 phylogenetic tree

## Overview

This step builds an HPV16 phylogenetic tree from prepared sequence inputs
(references + selected outgroups + sample consensus sequences).

## Implementation

- Pipeline: `pipelines/phylo_tree.nf`
- User config: `config/user.config`
- Step path config: `bin/config/targeted-analysis-hpv16-hpv18.config` (profile `targeted_hpv16_tree`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/phylo_tree.config` + `config/pipelines/phylo_tree.hpv16.config`
- Inputs directory: `intermediate_files/refdata/hpv16_tree` (wired via technical config)
- Outgroup list: `metadata/hpv16_tree_outgroups.txt`

Wrappers:

- `bin/targeted-analysis-hpv16-hpv18.steps/003.0.hpv16_tree.run.sh`

## Inputs

Inputs are expected under `intermediate_files/refdata/hpv16_tree/` and are prepared from
raw inputs under `refdata/hpv16_tree/` using scripts documented in the
repository root `README.md`.

## Outputs

- Tree outputs and intermediate artifacts under `output/`
- MultiQC report: `output/reports/multiqc_report.html`

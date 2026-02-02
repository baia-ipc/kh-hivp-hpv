# analysis-input1 step 003: VirStrain

## Overview

This step runs VirStrain on bucketed reads to infer HPV strain composition and
produces per-sample VirStrain reports plus an aggregated summary table.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/virstrain.nf`
- User config: `config/virstrain.config`
- Step path config: `bin/config/analysis-input1_003.virstrain.config` (internal defaults)
- Technical config: `pipelines/config/common.technical.config` + `pipelines/config/virstrain.technical.config`
- Bucket selection: `params.bucket_tid` in `pipelines/config/virstrain.technical.config`

Wrappers:

- `bin/003.0.virstrain.run.sh` (all samples)
- `bin/sample/003.0.virstrain.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`analysis-input1/001.0.centrifuge/output/`)
- VirStrain reference/index: configured in `config/virstrain.config`

## Outputs

Aggregated reports (`reports/`):

- `strains.tsv` (aggregated VirStrain results)
- MultiQC report: `reports/multiqc_report.html`

Per sample (`output/<RUN_ID>/<SAMPLE_ID>/`):

- `VirStrain_report.txt`
- `VirStrain_report.html`

# preliminary-analysis-all-patients step 003: VirStrain

## Overview

This step runs VirStrain on bucketed reads to infer HPV strain composition and
produces per-sample VirStrain reports plus an aggregated summary table.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/virstrain.nf`
- User config: `config/user.config`
- Step path config: `bin/config/preliminary-analysis-all-patients.config` (profile `preliminary_virstrain`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/virstrain.config`
- Bucket selection: `params.bucket_tid` in `config/pipelines/virstrain.config`

Wrappers:

- `bin/preliminary-analysis-all-patients.steps/003.0.virstrain.run.sh` (all samples)
- `bin/preliminary-analysis-all-patients.steps/single_sample/003.0.virstrain.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`preliminary-analysis-all-patients/001.0.centrifuge/output/`)
- VirStrain reference/index: wired via `config/pipelines/virstrain.config`

## Outputs

Aggregated reports (`reports/`):

- `strains.tsv` (aggregated VirStrain results)
- MultiQC report: `reports/multiqc_report.html`

Per sample (`output/<RUN_ID>/<SAMPLE_ID>/`):

- `VirStrain_report.txt`
- `VirStrain_report.html`

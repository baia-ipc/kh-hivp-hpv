# prelim_analysis step 003: VirStrain

## Overview

This step runs VirStrain on bucketed reads to infer HPV strain composition and
produces per-sample VirStrain reports plus an aggregated summary table.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/virstrain.nf`
- User config: `config/user.config`
- Step path config: `bin/config/prelim_analysis.config` (profile `preliminary_virstrain`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/virstrain.config`
- Bucket selection: `params.bucket_tid` in `config/pipelines/virstrain.config`

Wrappers:

- `bin/prelim_analysis.steps/003.0.virstrain.run.sh` (all samples)
- `bin/prelim_analysis.steps/single_sample/003.0.virstrain.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`prelim_analysis/001.0.centrifuge/output/`)
- VirStrain reference/index: wired via `config/pipelines/virstrain.config`

## Outputs

Aggregated reports (`reports/`):

- `strains.tsv` (aggregated VirStrain results)
- MultiQC report: `reports/multiqc_report.html`

Per sample (`output/<RUN_ID>/<SAMPLE_ID>/`):

- `VirStrain_report.txt`
- `VirStrain_report.html`

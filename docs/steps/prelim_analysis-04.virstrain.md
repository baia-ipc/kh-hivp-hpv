# prelim_analysis step 04: VirStrain

## Overview

This step runs VirStrain on bucketed reads to infer HPV strain composition and
produces per-sample VirStrain reports plus an aggregated summary table.
It is optional and does not run unless `--run-virstrain` is provided.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/virstrain.nf`
- User config: `config/user.config`
- Step path config: `config/analyses/prelim_analysis.config` (profile `preliminary_virstrain`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/virstrain.config`
- Bucket selection: `params.bucket_tid` in `config/pipelines/virstrain.config`

Wrappers:

- `bin/prelim_analysis.steps/04.virstrain.run.sh --run-virstrain` (all samples)
- `bin/prelim_analysis.steps/single_sample/04.virstrain.run_sample.sh --run-virstrain` (single sample pair)

## Inputs

- Reads directory: output of step 01 (`prelim_analysis/01.bucketing/output/`)
- VirStrain reference/index: wired via `config/pipelines/virstrain.config`

## Outputs

Aggregated reports (`reports/`):

- `strains.tsv` (aggregated VirStrain results)
- MultiQC report: `reports/multiqc_report.html`

Per sample (`output/<RUN_ID>/<SAMPLE_ID>/`):

- `VirStrain_report.txt`
- `VirStrain_report.html`

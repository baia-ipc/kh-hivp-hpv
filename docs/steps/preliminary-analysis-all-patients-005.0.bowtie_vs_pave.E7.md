# preliminary-analysis-all-patients step 005: PAVE E7 mapping

## Overview

This step maps bucketed reads against the PAVE reference and computes depth /
coverage statistics for the E7 gene region, producing per-sample statistics and
aggregated depth tables.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/pave_gene_mapping.nf`
- User config: `config/user.config`
- Step path config: `bin/config/preliminary-analysis-all-patients.config` (profile `preliminary_pave_e7`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/pave_gene_mapping.config`
- Bucket selection: `params.bucket_tid` in `config/pipelines/pave_gene_mapping.config`

Wrappers:

- `bin/preliminary-analysis-all-patients.steps/005.0.bowtie_vs_pave.E7.run.sh` (all samples)
- `bin/preliminary-analysis-all-patients.steps/single_sample/005.0.bowtie_vs_pave.E7.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`preliminary-analysis-all-patients/001.0.centrifuge/output/`)
- PAVE reference and gene coordinates: configured in `bin/config/preliminary-analysis-all-patients.config` (profile `preliminary_pave_e7`)

## Outputs

Per run (`output/<RUN_ID>/`):

- per-sample mapping/depth artifacts

Aggregated, step-level reports (`reports/`):

- `strains.tsv`
- `depth_stats.unfiltered.tsv`
- `depth_stats.filtered.tsv`
- MultiQC report: `reports/multiqc_report.html`

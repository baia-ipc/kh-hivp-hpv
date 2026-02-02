# analysis-input1 step 005: PAVE E7 mapping

## Overview

This step maps bucketed reads against the PAVE reference and computes depth /
coverage statistics for the E7 gene region, producing per-sample statistics and
aggregated depth tables.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/pave_gene_mapping.nf`
- User config: `config/general.config`
- Step path config: `bin/config/pave_e7.config` (internal defaults)
- Technical config: `pipelines/config/common.technical.config` + `pipelines/config/pave_gene_mapping.technical.config`
- Bucket selection: `params.bucket_tid` in `pipelines/config/pave_gene_mapping.technical.config`

Wrappers:

- `bin/005.0.bowtie_vs_pave.E7.run.sh` (all samples)
- `bin/sample/005.0.bowtie_vs_pave.E7.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`analysis-input1/001.0.centrifuge/output/`)
- PAVE reference and gene coordinates: configured in `bin/config/pave_e7.config`

## Outputs

Per run (`output/<RUN_ID>/`):

- per-sample mapping/depth artifacts

Aggregated, step-level reports (`reports/`):

- `strains.tsv`
- `depth_stats.unfiltered.tsv`
- `depth_stats.filtered.tsv`
- MultiQC report: `reports/multiqc_report.html`

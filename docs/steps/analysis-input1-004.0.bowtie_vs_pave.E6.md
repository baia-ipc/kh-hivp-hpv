# analysis-input1 step 004: PAVE E6 mapping

## Overview

This step maps bucketed reads against the PAVE reference and computes depth /
coverage statistics for the E6 gene region, producing per-sample statistics and
aggregated depth tables.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/pave_gene_mapping.nf`
- Config: `config/pave_e6.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `analysis-input1/004.0.bowtie_vs_pave.E6/scripts/run_all.sh` (all samples)
- `analysis-input1/004.0.bowtie_vs_pave.E6/scripts/run.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`analysis-input1/001.0.centrifuge/output/`)
- PAVE reference and gene coordinates: configured in `config/pave_e6.config`

## Outputs

Per run (`output/<RUN_ID>/`):

- per-sample mapping/depth artifacts

Aggregated, step-level reports (`reports/`):

- `strains.tsv`
- `depth_stats.unfiltered.tsv`
- `depth_stats.filtered.tsv`
- MultiQC report: `reports/multiqc_report.html`


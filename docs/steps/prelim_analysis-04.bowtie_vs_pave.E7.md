# prelim_analysis step 04: PAVE E7 mapping

## Overview

This step maps bucketed reads against the PAVE reference and computes depth /
coverage statistics for the E7 gene region, producing per-sample statistics and
aggregated depth tables.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/pave_gene_mapping.nf`
- User config: `config/user.config`
- Step path config: `bin/config/prelim_analysis.config` (profile `preliminary_pave_e7`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/pave_gene_mapping.config`
- Bucket selection: `params.bucket_tid` in `config/pipelines/pave_gene_mapping.config`

Wrappers:

- `bin/prelim_analysis.steps/04.bowtie_vs_pave.E7.run.sh` (all samples)
- `bin/prelim_analysis.steps/single_sample/04.bowtie_vs_pave.E7.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 01 (`prelim_analysis/01.centrifuge/output/`)
- PAVE reference and gene coordinates: configured in `bin/config/prelim_analysis.config` (profile `preliminary_pave_e7`)

## Outputs

Per run (`output/<RUN_ID>/`):

- per-sample mapping/depth artifacts

Aggregated, step-level reports (`reports/`):

- `strains.tsv`
- `depth_stats.unfiltered.tsv`
- `depth_stats.filtered.tsv`
- MultiQC report: `reports/multiqc_report.html`

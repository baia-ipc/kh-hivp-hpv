# prelim_analysis step 03: PAVE E6 mapping

## Overview

This step maps bucketed reads against the PAVE reference and computes depth /
coverage statistics for the E6 gene region, producing per-sample statistics and
aggregated depth tables.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/pave_gene_mapping.nf`
- User config: `config/user.config`
- Step path config: `config/analyses/prelim_analysis.config` (profile `preliminary_pave_e6`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/pave_gene_mapping.config`
- Bucket selection: `params.bucket_tid` in `config/pipelines/pave_gene_mapping.config`

Wrappers:

- `bin/prelim_analysis.steps/03.bowtie_vs_pave.E6.run.sh` (all samples)
- `bin/prelim_analysis.steps/single_sample/03.bowtie_vs_pave.E6.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 01 (`prelim_analysis/01.centrifuge/output/`)
- PAVE reference and gene coordinates: configured in `config/analyses/prelim_analysis.config` (profile `preliminary_pave_e6`)

## Outputs

Per run (`output/<RUN_ID>/`):

- per-sample mapping/depth artifacts

Aggregated, step-level reports (`reports/`):

- `strains.tsv`
- `depth_stats.unfiltered.tsv`
- `depth_stats.filtered.tsv`
- MultiQC report: `reports/multiqc_report.html`

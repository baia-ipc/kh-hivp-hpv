# analysis-input2 step 002: Bowtie vs PAVE

## Overview

This step maps bucketed reads (from analysis-input2 step 001) to the PAVE
reference using Bowtie2, summarizes mapping by strain, computes coverage
statistics, performs variant calling, and annotates E6/E7 variants with
amino‑acid consequences.

## Implementation

- Pipeline: `pipelines/bowtie_vs_pave.nf`
- Config: `config/bowtie_vs_pave.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `analysis-input2/002.0.mapping_vs_pave/scripts/run_all.sh` (all samples)
- `analysis-input2/002.0.mapping_vs_pave/scripts/run.sh` (single sample pair)

## Inputs

- Reads directory: output of analysis-input2 step 001 (`analysis-input2/001.0.bucketing/output/`)

## Outputs

- Outputs under `output/<RUN_ID>/`
- Reports under `reports/`, including:
  - mapping/coverage summaries
  - E6/E7 variant effects (amino‑acid consequences)
  - `reports/multiqc_report.html`

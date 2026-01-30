# analysis-input2 step 002: Bowtie vs PAVE

## Overview

This step maps bucketed reads (from analysis-input2 step 001) to the PAVE
reference using Bowtie2, summarizes mapping by strain, computes coverage
statistics, performs variant calling, and annotates E6/E7 variants with
amino‑acid consequences. It also compares sample E6/E7 SNPs against
lineage‑defining SNPs from HPV16/HPV18 lineage references.

## Implementation

- Pipeline: `pipelines/bowtie_vs_pave.nf`
- Config: `config/bowtie_vs_pave.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `analysis-input2/002.0.mapping_vs_pave/scripts/run_all.sh` (all samples)
- `analysis-input2/002.0.mapping_vs_pave/scripts/run.sh` (single sample pair)

## Inputs

- Reads directory: output of analysis-input2 step 001 (`analysis-input2/001.0.bucketing/output/`)
- Lineage references: `refdata/hpv16_tree/lineages_ref_renamed.fasta` and
  `refdata/hpv18_tree/lineages_ref_renamed.fasta`

## Outputs

- Outputs under `output/<RUN_ID>/`
- Reports under `reports/`, including:
  - mapping/coverage summaries
  - E6/E7 variant effects (amino‑acid consequences)
  - lineage SNP comparison table
  - `reports/multiqc_report.html`

# analysis-input2 step 002: Bowtie vs PAVE

## Overview

This step maps bucketed reads (from analysis-input2 step 001) to the PAVE
reference using Bowtie2, summarizes mapping by strain, computes coverage
statistics, performs variant calling, and annotates E6/E7 variants with
amino‑acid consequences. It also compares sample E6/E7 SNPs against
lineage‑defining SNPs from HPV16/HPV18 lineage references.

## Implementation

- Pipeline: `pipelines/bowtie_vs_pave.nf`
- User configs: `config/bowtie_vs_pave.config` + `config/analysis-input2_002.mapping_vs_pave.config`
- Technical config: `pipelines/config/common.technical.config` + `pipelines/config/bowtie_vs_pave.technical.config`
- Bucket selection: `config/pave_bucket_tid.txt`

Wrappers:

- `bin/002.0.mapping_vs_pave.run.sh` (all samples)
- `bin/sample/002.0.mapping_vs_pave.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of analysis-input2 step 001 (`analysis-input2/001.0.bucketing/output/`)
- PAVE reference inputs (see `config/bowtie_vs_pave.config`):
  - Reference FASTA: `refdata/raw/pave/pave_hsa.fas`
  - GFF3 directory: `refdata/raw/pave/gff3`
  - BED directory: `refdata/raw/pave/bed`
  - Feature tables (derived): `refdata/derived/pave/features_tsv` (generated from GFF3 with `scripts/gff3_to_features_tsv.run_all.sh`)
- Lineage references: `refdata/derived/hpv16_tree/lineages_ref_renamed.fasta` and
  `refdata/derived/hpv18_tree/lineages_ref_renamed.fasta`

## Outputs

- Outputs under `output/<RUN_ID>/`
- Reports under `reports/`, including:
  - mapping/coverage summaries
  - E6/E7 variant effects (amino‑acid consequences)
  - lineage SNP comparison table
  - `reports/multiqc_report.html`

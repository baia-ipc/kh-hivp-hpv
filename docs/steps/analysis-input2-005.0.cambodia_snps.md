# analysis-input2 step 005: Cambodia SNP comparison

## Overview

This step extracts HPV16/HPV18 genomes from the selected reference sets that
originate from Cambodia, calls E6/E7 SNPs against the PAVE reference, and
compares those SNPs to (1) lineage‑defining SNPs and (2) the E6/E7 variants
observed in analysis-input2 step 002.

## Implementation

- Pipeline: `pipelines/cambodia_snps.nf`
- Config: `config/cambodia_snps.config`

Wrappers:

- `analysis-input2/005.0.cambodia_snps/scripts/run_all.sh`

## Inputs

- Selected genomes and country metadata:
  - `refdata/derived/hpv16_tree/selected.fasta`
  - `refdata/derived/hpv16_tree/selected`
  - `refdata/derived/hpv18_tree/selected.fasta`
  - `refdata/derived/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv`
- Lineage references:
  - `refdata/derived/hpv16_tree/lineages_ref_renamed.fasta`
  - `refdata/derived/hpv18_tree/lineages_ref_renamed.fasta`
- Sample variants from step 002:
  - `analysis-input2/002.0.mapping_vs_pave/reports/E6_E7_variants.tsv`

## Outputs

- Extracted Cambodian FASTA files under `output/`:
  - `cambodia_hpv16.fasta`
  - `cambodia_hpv18.fasta`
- Reports under `reports/`:
  - `cambodia_snps.tsv`
  - `lineage_snps.tsv`
  - `cambodia_lineage_comparison.tsv`
  - `cambodia_sample_comparison.tsv`
  - `samples_vs_cambodia.tsv`
  - `samples_vs_cambodia_sets.tsv`
  - `samples_vs_lineage_sets.tsv`
  - `multiqc_report.html`

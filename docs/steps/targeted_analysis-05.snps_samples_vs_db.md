# targeted_analysis step 05: SNPs (samples vs database)

## Overview

This step extracts HPV16/HPV18 genomes from the selected reference sets that
match the configured target country, calls E6/E7 SNPs against the PAVE reference, and
compares those SNPs to (1) lineage‑defining SNPs and (2) the E6/E7 variants
observed in targeted_analysis step 02.

## Implementation

- Pipeline: `pipelines/database_snps.nf`
- User config: `config/user.config`
- Step path config: `bin/config/targeted_analysis.config` (profile `targeted_snps_samples_vs_db`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/database_snps.config`

Wrappers:

- `bin/targeted_analysis.steps/05.snps_samples_vs_db.run.sh`

## Inputs

- Selected genomes and country metadata:
  - `derived_data/refdata/hpv16_tree/selected.fasta`
  - `derived_data/refdata/hpv16_tree/selected`
  - `derived_data/refdata/hpv18_tree/selected.fasta`
  - `derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv`
- Lineage references:
  - `derived_data/refdata/hpv16_tree/lineages_ref_renamed.fasta`
  - `derived_data/refdata/hpv18_tree/lineages_ref_renamed.fasta`
- PAVE BED directory: `derived_data/refdata/pave/bed` (auto-generated from `refdata/pave/gff3` if missing)
- Sample variants from step 02:
  - `targeted_analysis/02.mapping_vs_pave/reports/E6_E7_variants.tsv`

## Outputs

- Extracted database FASTA files under `output/`:
  - `database_hpv16.fasta`
  - `database_hpv18.fasta`
- Reports under `reports/`:
  - `database_snps.tsv`
  - `lineage_snps.tsv`
  - `database_lineage_comparison.tsv`
  - `database_sample_comparison.tsv`
  - `samples_vs_database.tsv`
  - `samples_vs_database_sets.tsv`
  - `samples_vs_lineage_sets.tsv`
  - `multiqc_report.html`

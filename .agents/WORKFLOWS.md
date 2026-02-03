# WORKFLOWS

Ordered view of steps and dependencies across analyses (happy path).

Rules:
- Do not add command lines here (put them in `.agents/OPERATIONS.md`).
- Do not describe tools/config locations here beyond what is needed for dependencies (put full catalog info in `.agents/SKILLS.md`).

## Workflow: prelim_analysis

1) Centrifuge bucketing (Nextflow)
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples-input1.tsv`
   - Outputs: `prelim_analysis/01.centrifuge/output`, `prelim_analysis/01.centrifuge/reports`

2) Bowtie vs PAVE mapping
   - Depends on: step 01 `prelim_analysis/01.centrifuge/output`
   - Outputs: `prelim_analysis/02.bowtie_vs_pave/output`, `prelim_analysis/02.bowtie_vs_pave/reports`

3) VirStrain reports (optional)
   - Depends on: step 01 `prelim_analysis/01.centrifuge/output`
   - Outputs: `prelim_analysis/05.virstrain/output`, `prelim_analysis/05.virstrain/reports`

## Workflow: targeted_analysis (mapping)

1) Bucketing
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples-input2.tsv`
   - Outputs: `targeted_analysis/01.bucketing/output`, `targeted_analysis/01.bucketing/reports`

2) Mapping vs PAVE
   - Depends on: step 01 `targeted_analysis/01.bucketing/output`
   - Outputs: `targeted_analysis/02.mapping_vs_pave/output`, `targeted_analysis/02.mapping_vs_pave/reports`

3) SNPs samples vs database
   - Depends on: step 02 reports (`targeted_analysis/02.mapping_vs_pave/reports/E6_E7_variants.tsv`)
   - Outputs: `targeted_analysis/05.snps_samples_vs_db/output`, `targeted_analysis/05.snps_samples_vs_db/reports`

## Workflow: phylogenetic trees

- HPV16 depends on:
  - prepared inputs under `derived_data/refdata/hpv16_tree` (from raw inputs in `refdata/hpv16_tree`)
  - (for sample consensus) mapping outputs under `targeted_analysis/02.mapping_vs_pave/output`
- HPV18 depends on:
  - prepared inputs under `derived_data/refdata/hpv18_tree` (from raw inputs in `refdata/hpv18_tree`)
  - (for sample consensus) mapping outputs under `targeted_analysis/02.mapping_vs_pave/output`
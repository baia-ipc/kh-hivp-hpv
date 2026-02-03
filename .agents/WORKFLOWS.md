# WORKFLOWS

Ordered view of steps and dependencies across analyses (happy path).

Rules:
- Do not add command lines here (put them in `.agents/OPERATIONS.md`).
- Do not describe tools/config locations here beyond what is needed for dependencies (put full catalog info in `.agents/SKILLS.md`).

## Workflow: prelim_analysis

1) Centrifuge bucketing (Nextflow)
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples-input1.tsv`
   - Outputs: `prelim_analysis/001.0.centrifuge/output`, `prelim_analysis/001.0.centrifuge/reports`

2) Bowtie vs PAVE mapping
   - Depends on: step 001 `prelim_analysis/001.0.centrifuge/output`
   - Outputs: `prelim_analysis/002.0.bowtie_vs_pave/output`, `prelim_analysis/002.0.bowtie_vs_pave/reports`

3) VirStrain reports
   - Depends on: step 001 `prelim_analysis/001.0.centrifuge/output`
   - Outputs: `prelim_analysis/003.0.virstrain/output`, `prelim_analysis/003.0.virstrain/reports`

4) E6/E7 sub-analyses
   - Depends on: step 001 `prelim_analysis/001.0.centrifuge/output`
   - E6 outputs: `prelim_analysis/004.0.bowtie_vs_pave.E6/output`, `prelim_analysis/004.0.bowtie_vs_pave.E6/reports`
   - E7 outputs: `prelim_analysis/005.0.bowtie_vs_pave.E7/output`, `prelim_analysis/005.0.bowtie_vs_pave.E7/reports`

## Workflow: targeted_analysis (mapping)

1) Bucketing
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples-input2.tsv`
   - Outputs: `targeted_analysis/001.0.bucketing/output`, `targeted_analysis/001.0.bucketing/reports`

2) Mapping vs PAVE
   - Depends on: step 001 `targeted_analysis/001.0.bucketing/output`
   - Outputs: `targeted_analysis/002.0.mapping_vs_pave/output`, `targeted_analysis/002.0.mapping_vs_pave/reports`

3) SNPs samples vs database
   - Depends on: step 002 reports (`targeted_analysis/002.0.mapping_vs_pave/reports/E6_E7_variants.tsv`)
   - Outputs: `targeted_analysis/005.0.snps_samples_vs_db/output`, `targeted_analysis/005.0.snps_samples_vs_db/reports`

## Workflow: phylogenetic trees

- HPV16 depends on:
  - prepared inputs under `intermediate_files/refdata/hpv16_tree` (from raw inputs in `refdata/hpv16_tree`)
  - (for sample consensus) mapping outputs under `targeted_analysis/002.0.mapping_vs_pave/output`
- HPV18 depends on:
  - prepared inputs under `intermediate_files/refdata/hpv18_tree` (from raw inputs in `refdata/hpv18_tree`)
  - (for sample consensus) mapping outputs under `targeted_analysis/002.0.mapping_vs_pave/output`

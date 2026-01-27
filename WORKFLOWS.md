# WORKFLOWS

Ordered view of steps and dependencies across analyses (happy path).

Rules:
- Do not add command lines here (put them in `OPERATIONS.md`).
- Do not describe tools/config locations here beyond what is needed for dependencies (put full catalog info in `SKILLS.md`).

## Workflow: analysis-input1

1) Centrifuge bucketing (Nextflow)
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples-input1.tsv`
   - Outputs: `analysis-input1/001.0.centrifuge/output`, `analysis-input1/001.0.centrifuge/reports`

2) Bowtie vs PAVE mapping
   - Depends on: step 001 `analysis-input1/001.0.centrifuge/output`
   - Outputs: `analysis-input1/002.0.bowtie_vs_pave/output`, `analysis-input1/002.0.bowtie_vs_pave/reports`

3) VirStrain reports
   - Depends on: step 001 `analysis-input1/001.0.centrifuge/output`
   - Outputs: `analysis-input1/003.0.virstrain/output`, `analysis-input1/003.0.virstrain/reports`

4) E6/E7 sub-analyses
   - Depends on: step 001 `analysis-input1/001.0.centrifuge/output`
   - E6 outputs: `analysis-input1/004.0.bowtie_vs_pave.E6/output`, `analysis-input1/004.0.bowtie_vs_pave.E6/reports`
   - E7 outputs: `analysis-input1/005.0.bowtie_vs_pave.E7/output`, `analysis-input1/005.0.bowtie_vs_pave.E7/reports`

## Workflow: analysis-input2 (mapping)

1) Bucketing
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples-input2.tsv`
   - Outputs: `analysis-input2/001.0.bucketing/output`, `analysis-input2/001.0.bucketing/reports`

2) Mapping vs PAVE
   - Depends on: step 001 `analysis-input2/001.0.bucketing/output`
   - Outputs: `analysis-input2/002.0.mapping_vs_pave/output`, `analysis-input2/002.0.mapping_vs_pave/reports`

## Workflow: phylogenetic trees

- HPV16 depends on:
  - prepared inputs under `analysis-input2/003.0.hpv16_tree/input`
  - (for sample consensus) mapping outputs under `analysis-input2/002.0.mapping_vs_pave/output`
- HPV18 depends on:
  - prepared inputs under `analysis-input2/004.0.hpv18_tree/input`
  - (for sample consensus) mapping outputs under `analysis-input2/002.0.mapping_vs_pave/output`

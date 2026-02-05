# WORKFLOWS

Ordered view of steps and dependencies across analyses (happy path).

Rules:
- Do not add command lines here (put them in `.agents/OPERATIONS.md`).
- Do not describe tools/config locations here beyond what is needed for dependencies (put full catalog info in `.agents/SKILLS.md`).

## Workflow: prelim_analysis

1) Bucketing (Nextflow)
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples_prelim_analysis.tsv`
   - Outputs: `outs/prelim_analysis/01.bucketing`, `outs/prelim_analysis/01.bucketing/reports`

2) Mapping vs PAVE
   - Depends on: step 01 `outs/prelim_analysis/01.bucketing`
   - Outputs: `outs/prelim_analysis/02.mapping_vs_pave`, `outs/prelim_analysis/02.mapping_vs_pave/reports`

3) Variant analysis
   - Depends on: step 02 `outs/prelim_analysis/02.mapping_vs_pave`
   - Outputs: `outs/prelim_analysis/03.variant_analysis/reports`

4) VirStrain reports (optional)
   - Depends on: step 01 `outs/prelim_analysis/01.bucketing`
   - Outputs: `outs/prelim_analysis/04.virstrain`, `outs/prelim_analysis/04.virstrain/reports`

## Workflow: targeted_analysis (mapping)

1) Bucketing
   - Purpose: classify reads and create per-sample bucket FASTQs.
   - Inputs: `metadata/samples_targeted_analysis.tsv`
   - Outputs: `outs/targeted_analysis/01.bucketing`, `outs/targeted_analysis/01.bucketing/reports`

2) Mapping vs PAVE
   - Depends on: step 01 `outs/targeted_analysis/01.bucketing`
   - Outputs: `outs/targeted_analysis/02.mapping_vs_pave`, `outs/targeted_analysis/02.mapping_vs_pave/reports`

3) Variant analysis (includes optional database comparison)
   - Depends on: step 02 outputs (`outs/targeted_analysis/02.mapping_vs_pave`)
   - Outputs: `outs/targeted_analysis/03.variant_analysis/reports`
   - Database comparison outputs: `outs/targeted_analysis/03.variant_analysis/database_snps` and tables in `outs/targeted_analysis/03.variant_analysis/reports`

## Workflow: phylogenetic trees

- HPV16 depends on:
  - prepared inputs under `derived_data/refdata/hpv16_tree` (from raw inputs in `refdata/hpv16_tree`)
  - (for sample consensus) mapping outputs under `outs/targeted_analysis/02.mapping_vs_pave`
- Outputs include alignment/tree artifacts under `outs/targeted_analysis/04.hpv16_tree` and a MultiQC report with an offline tree preview (under `results/reports/targeted_analysis/`).
- HPV18 depends on:
  - prepared inputs under `derived_data/refdata/hpv18_tree` (from raw inputs in `refdata/hpv18_tree`)
  - (for sample consensus) mapping outputs under `outs/targeted_analysis/02.mapping_vs_pave`
- Outputs include alignment/tree artifacts under `outs/targeted_analysis/05.hpv18_tree` and a MultiQC report with an offline tree preview (under `results/reports/targeted_analysis/`).
- Optional: lineage annotations can be generated for tree tips using the lineage reference lists in `metadata/`.

Curated outputs (selected reports/sequences) can be copied under `results/`.

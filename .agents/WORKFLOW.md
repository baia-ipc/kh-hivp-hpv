# WORKFLOW

Stable happy-path execution order. No commands here.

## prelim_analysis

1. `01.bucketing`
2. `02.mapping_vs_pave` (depends on step 01)
3. `03.variant_analysis` (depends on step 02)
4. `04.virstrain` optional (depends on step 01)

## targeted_analysis

1. `01.bucketing`
2. `02.mapping_vs_pave` (depends on step 01)
3. `03.variant_analysis` (depends on step 02; optional DB branch inside step)
4. `04.hpv16_tree` (depends on tree inputs + mapping outputs)
5. `05.hpv18_tree` (depends on tree inputs + mapping outputs)

Notes:
- Tree steps may need explicit `bcf_run_id` in
  `config/analyses/targeted_analysis.config` when mapping outputs include
  multiple run IDs.

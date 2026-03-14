# Recombination Analysis Metadata

This directory stores metadata-driven input selections for
`06.recombination_analysis`.

## Files

- `sequence_sets/targeted_analysis.recombination_sequences.tsv`
  - Required columns: `run_id`, `sample_id`, `hpv_type`, `fasta_path`
  - `fasta_path` can be absolute or repo-relative.
- `exclude_lists/default_controls.txt`
  - Optional explicit sample IDs to exclude.
- `hpv_type_groups/high_risk_hpv_types.txt`
  - Optional HPV type list for filtering.

Controls/technical artifacts should be excluded from summaries unless
a QC-specific task requires them.

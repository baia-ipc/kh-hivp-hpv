---
name: output-comparison
description: Compare generated analysis outputs against references or prior runs and report meaningful differences with file-level evidence.
---

# Output Comparison

Use this skill for regression checks against `reference-results` or earlier runs.

## Procedure

1. Compare report files first (`results/reports/...`, then step `outs/.../reports/...`).
2. Compare key TSV tables with row/column-level checks.
3. Prioritize behavior-impacting differences over formatting-only differences.

## Reporting rules

- Highlight exact file paths and affected fields/rows.
- Exclude controls/technical artifacts from prevalence/proportion analysis unless
  explicitly doing QC (`H2O`, `HPV-110`, `Ex`, `HPV-19`, `Undetermined`).

## Follow-up

- If a difference appears to be a bug, identify likely root cause and the
  pipeline/config location to patch.
- Re-run only necessary steps to validate the fix.

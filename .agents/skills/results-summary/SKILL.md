---
name: results-summary-authoring
description: Write repository-compliant METHODS_AND_RESULTS summaries from pipeline outputs, including prose-first structure, artifact exclusion rules, and sample listing conventions.
---

# Results Summary Authoring

Use this skill when creating or updating `METHODS_AND_RESULTS.md` files.

## Required style

- Prose-first narrative; tables support the narrative, not vice versa.
- Cite exact source tables/files used for key values.

## Inclusion and exclusion rules

- Exclude controls/technical artifacts from result summaries unless task is
  explicitly QC:
  - `H2O`, `HPV-110`, `Ex`, `HPV-19`, and Illumina `Undetermined` reads.

## Sample listing rule

- When affected sample count is small (<=5, or <=10 if central to the point),
  list explicit `RunID:SampleID` values in the text.

## Sanity checks before commit

1. Numbers in prose match source tables.
2. Any percentage/proportion statement excludes technical artifacts unless QC.
3. File paths in the summary resolve to current `outs/.../reports/...` inputs.

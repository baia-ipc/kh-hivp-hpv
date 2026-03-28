# targeted_analysis step 07: Recombination OpenRDP

## Overview

This step runs only the slow OpenRDP candidate scan on the published outputs
from step 06, then writes an OpenRDP-focused handoff for downstream
confirmation.

## Implementation

- Pipeline: `pipelines/recombination_analysis.nf`
- Wrapper: `bin/targeted_analysis.steps/07.recombination_openrdp.run.sh`
- Step config JSON: `config/steps/targeted_analysis.07.recombination_openrdp.json`
- Analysis profile: `config/analyses/targeted_analysis.config` (`targeted_recombination_openrdp`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/recombination_analysis.config`
- User parameters: `config/user.config` (keys prefixed with `recombination_`)

## Inputs

- Published stage-06 handoff:
  - `outs/targeted_analysis/06.recombination_screen/summary/recombination_screen_groups.tsv`
- The handoff rows point to published stage-06 artifacts:
  - aligned FASTA
  - manifest and duplicate-map TSVs
  - representative IDs and group summary JSON
  - GARD JSON, breakpoint table, summary JSON, warnings, and log

## Outputs

Primary output root:

- `outs/targeted_analysis/07.recombination_openrdp/`

Subdirectories:

- `openrdp/`: parsed candidate tables, summaries, raw CSV, and logs
- `summary/`: OpenRDP overview tables, warnings, and `recombination_openrdp_groups.tsv`
- `reports/`: MultiQC-ready OpenRDP tables and markdown summary

MultiQC report:

- `results/reports/targeted_analysis/07_recombination_openrdp.report.html`

## Notes

- The wrapper preserves per-method OpenRDP failure tolerance; a failing method
  is recorded in the summary instead of aborting the whole stage when other
  methods still complete.
- Stage 08 consumes `summary/recombination_openrdp_groups.tsv`.

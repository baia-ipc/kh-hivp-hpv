---
name: analysis-execution-nextflow
description: Run and troubleshoot analysis wrappers and Nextflow steps in this repository, including rerun/resume strategy and output-path verification.
---

# Analysis Execution (Nextflow/Wrappers)

Use this skill when asked to run or validate analysis steps.

## Preconditions

- Apply `.agents/skills/nextflow/SKILL.md` first.
- Prefer wrapper entrypoints under `bin/` over raw `nextflow run`.

## Standard Entry Points

- Whole analyses:
  - `bin/prelim_analysis.run.sh`
  - `bin/targeted_analysis.run.sh`
- Optional prelim VirStrain:
  - `bin/prelim_analysis.run.sh --run-virstrain`
- Step wrappers:
  - `bin/prelim_analysis.steps/01.bucketing.run.sh`
  - `bin/prelim_analysis.steps/02.mapping_vs_pave.run.sh`
  - `bin/prelim_analysis.steps/03.variant_analysis.run.sh`
  - `bin/prelim_analysis.steps/04.virstrain.run.sh`
  - `bin/targeted_analysis.steps/01.bucketing.run.sh`
  - `bin/targeted_analysis.steps/02.mapping_vs_pave.run.sh`
  - `bin/targeted_analysis.steps/03.variant_analysis.run.sh`
  - `bin/targeted_analysis.steps/04.hpv16_tree.run.sh`
  - `bin/targeted_analysis.steps/05.hpv18_tree.run.sh`

## Rerun Strategy

- Default: use resume-capable wrapper runs.
- For Nextflow task reuse, keep `-resume` enabled unless intentionally forcing
  recomputation.
- Force a step recompute by removing only that step output dir under `outs/`.
- Keep generated reports policy intact:
  - non-MultiQC in `outs/<analysis>/<step>/reports/`
  - MultiQC HTML in `results/reports/<analysis>/`.

## Verification Checklist

1. Expected step output directory exists under `outs/...`.
2. Expected MultiQC HTML exists under `results/reports/<analysis>/`.
3. No outputs appear under `null/` or `results/reports/unknown_analysis/`.
4. For downstream variant/VirStrain reports, check `Undetermined*` handling.
5. For tree steps, confirm `phylo_tree.svg` and `phylo_tree.png` are at step
   root and not under `reports/`.

## Troubleshooting

- Check `.nextflow.log` and task logs under `work/*/.command.{sh,out,err}`.
- For new Nextflow params, ensure they are declared in matching config files
  (`config/user.config` or `config/pipelines/*.config`) to avoid undefined
  parameter warnings.
- If cache/env paths drift, verify `NXF_HOME`, `CONDA_ENVS_PATH`,
  `CONDA_PKGS_DIRS` resolve to repo-root `.nextflow/` and `.conda/`.

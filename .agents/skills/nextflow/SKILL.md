---
name: nextflow-sandbox-runner
description: Standard environment contract for running Nextflow directly or via wrappers in sandboxed/offline sessions without recreating Conda envs or writing to unexpected paths.
---

# Nextflow Sandbox Runner

Use this skill whenever a command may invoke Nextflow:
- direct `nextflow run ...`
- shell wrappers under `bin/*.run.sh`
- Python wrappers like `bin/run_step.py`

Note: `bin/run_step.py` now enforces repo-root cache paths and overrides any
`CONDA_*`/`NXF_HOME` values pointing under `pipelines/.conda`.

## Environment preset

Export this block before launching the command:

```bash
export CONDA_OVERRIDE_CUDA=0
export JAVA_CMD=/usr/lib/jvm/java-21-openjdk-amd64/bin/java
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export NXF_HOME="$PWD/.nextflow"
export NXF_OFFLINE=true
export CONDA_PKGS_DIRS="$PWD/.conda/pkgs"
export CONDA_ENVS_PATH="$PWD/.conda/envs"
```

## Why these variables are required

- `CONDA_OVERRIDE_CUDA=0`: avoids `conda info --json` CUDA probing failures in restricted environments.
- `JAVA_CMD` and `JAVA_HOME`: pins a Java 17+ runtime for Nextflow; prevents accidental use of older Conda Java.
- `NXF_HOME="$PWD/.nextflow"`: keeps Nextflow state/cache inside the workspace and avoids user-specific absolute paths.
- `NXF_OFFLINE=true`: prevents network access attempts when the run should use already cached assets.
- `CONDA_PKGS_DIRS` and `CONDA_ENVS_PATH`: keeps package/env caches in-repo so reruns reuse environments instead of rebuilding them.
- The cache/env roots must stay at repo root (`$PWD/.nextflow`, `$PWD/.conda`);
  do not allow runtime state under `pipelines/.conda`.

## Execution pattern

Run any Nextflow caller in the same shell after exporting the preset.
Examples:

```bash
nextflow run pipelines/variant_analysis.nf ... -resume
python3 bin/run_step.py config/steps/targeted_analysis.03.variant_analysis.json
bin/targeted_analysis.steps/02.mapping_vs_pave.run.sh
```

## First-run and fallback behavior

- Keep `NXF_OFFLINE=true` for normal reruns.
- If required assets are not cached yet, run once with `NXF_OFFLINE=false`, then switch back to `true`.
- Keep the same values for `NXF_HOME`, `CONDA_PKGS_DIRS`, and `CONDA_ENVS_PATH` across steps to maximize `-resume` reuse.

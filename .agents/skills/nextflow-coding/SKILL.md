---
name: nextflow-code-authoring
description: Repo-specific guidance for writing and modifying Nextflow pipelines safely, including parameter contracts, Groovy/shell escaping, output path conventions, and MultiQC integration.
---

# Nextflow Code Authoring

Use this skill when adding or editing any `.nf` pipeline, step wrapper config in
`config/steps/*.json`, or related Nextflow parameter wiring.

## Scope and Preconditions

- Apply the runtime environment contract in `.agents/skills/nextflow/SKILL.md`
  before running Nextflow.
- Keep user-editable values in `config/` and metadata-driven values in
  `metadata/`.
- Never hardcode user-specific absolute paths.

## Repo Output Contract

- Step outputs: `outs/<analysis>/<step>/`
- Non-MultiQC reports: `outs/<analysis>/<step>/reports/`
- MultiQC reports: `results/reports/<analysis>/`
- MultiQC filename: `<step_name with dot replaced by underscore>.report.html`
- Phylo tree images (`phylo_tree.svg`, `phylo_tree.png`) belong at step root,
  not under `reports/`.

## Parameter Contract (avoid null/unknown path bugs)

In pipelines, prefer this pattern:

1. Initialize optional params with explicit defaults:
   - `params.analysis_name = params.analysis_name ?: null`
   - `params.step_name = params.step_name ?: "<nn.step>"`
   - `params.input_step_name = params.input_step_name ?: "<nn.step>"` (if used)
2. Resolve path params from `analysis_name` + `step_name`/`input_step_name`
   when not explicitly provided:
   - `outdir = <projectRoot>/outs/...`
   - `reports_dir = "${outdir}/reports"`
   - `multiqc_outdir = <projectRoot>/results/reports/<analysis>`
3. Guard against stale `unknown_analysis` targets:
   - if `multiqc_outdir` missing or contains `unknown_analysis`, recompute from
     `analysis_name`.
4. Validate required params early and fail with clear messages.
5. Add new params to the correct config file:
   - user-facing: `config/user.config`
   - technical/pipeline-specific: `config/pipelines/*.config`
   - analysis step path/profile: `config/analyses/*.config`

## Groovy + Shell Escaping Rules

Most runtime failures in script blocks come from accidental Groovy interpolation.
Inside `script: """ ... """`:

- Escape shell variable expansions:
  - use `\$var`, not `$var`
  - use `\${var%%.*}`, not `${var%%.*}`
- Escape command substitution:
  - use `\$(...)`, not `$(...)`
- Keep Nextflow/Groovy substitutions unescaped only when intentional:
  - `"${params.reports_dir}"` is correct for Nextflow params
- When iterating files from `find`, prefer robust quoting:
  - `while IFS= read -r f; do ...; done < <(find ...)`

Example safe pattern:

```nextflow
script:
"""
mkdir -p mapping_qc
while IFS= read -r f; do
  base=\$(basename "\$f")
  sample="\${base%%.*}"
  if [[ "\${sample,,}" == undetermined* ]]; then
    continue
  fi
  run_id=\$(basename "\$(dirname "\$f")")
  mkdir -p "mapping_qc/\$run_id"
  ln -sf "\$f" "mapping_qc/\$run_id/\$base"
done < <(find "${params.mapping_outdir}" -mindepth 2 -maxdepth 2 -type f)
"""
```

## Avoiding Staging Collisions in MultiQC

- Do not stage many files with identical basenames into one process input
  channel if they originate from multiple run directories.
- For collision-prone artifacts (for example `Undetermined.idxstats` from
  multiple runs), build a local structured view (`<run_id>/<filename>`) inside
  the process script.
- Exclude technical-artifact samples (`Undetermined*`) in downstream analyses
  (variant-analysis and VirStrain).
- Keep report responsibilities stable:
  - `mapping_vs_pave` MultiQC should focus on mapping/coverage summaries.
  - `General Statistics`, `Samtools`, and `Bcftools` sections should be shown
    in variant-analysis MultiQC.

## Wrapper and Step JSON Rules

- Keep per-step wrappers as thin shims that call `bin/run_step.py`.
- `config/steps/*.json`:
  - use `require_flag` for optional steps (for example VirStrain)
  - do not drop a required flag before pipeline evaluation
  - if needed, map aliases via `arg_transforms` (for example
    `--run-virstrain` to `--run_virstrain`)
- Rely on `bin/run_step.py` runtime normalization to keep caches under repo-root
  `.nextflow/` and `.conda/`, never `pipelines/.conda/`.

## Validation Checklist (before commit)

1. `nextflow config` or step wrapper invocation resolves expected `outdir`,
   `reports_dir`, and `multiqc_outdir`.
2. No output appears under `null/` or `results/reports/unknown_analysis/`.
3. Step outputs land in `outs/...`; only MultiQC HTML lands in
   `results/reports/...`.
4. MultiQC renders required sections and does not fail from file collisions.
5. `Undetermined*` handling is consistent with downstream policy.
6. Update `.agents` docs and `docs/CONTENTS.md` when introducing new conventions
   or directories.

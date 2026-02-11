# PROJECT

Compact project facts and current state for agent work.

## Repository Layout (canonical)

- `bin/`: analysis and step wrappers; includes generic runner `bin/run_step.py`.
- `config/`:
  - `config/user.config`: user-editable defaults.
  - `config/analyses/`: analysis/step path profiles.
  - `config/pipelines/`: technical Nextflow configuration.
  - `config/steps/`: JSON configs used by `bin/run_step.py`.
- `metadata/`: curated run/sample/tree metadata.
- `pipelines/`: Nextflow workflows; `pipelines/multiqc/` stores MultiQC YAML.
- `scripts/`: helper scripts grouped by domain.
- `refdata/`: raw reference inputs.
- `derived_data/`: generated references and shared indices (not tracked).
- `outs/`: step outputs and non-MultiQC reports (not tracked).
- `results/`: curated/selected tracked outputs; MultiQC HTML under
  `results/reports/<analysis>/`.

## Artifact Placement (operational)

- Step outputs and non-MultiQC reports are under `outs/<analysis>/<step>/`.
- MultiQC HTML reports are under `results/reports/<analysis>/`.
- Phylogenetic preview images are at step root (`phylo_tree.svg/.png`), not
  in `reports/`.

## Analysis Dependency Map (compact)

- `prelim_analysis`:
  - `01.bucketing` -> `02.mapping_vs_pave` -> `03.variant_analysis`
  - `04.virstrain` is optional and depends on `01.bucketing`.
- `targeted_analysis`:
  - `01.bucketing` -> `02.mapping_vs_pave` -> `03.variant_analysis` ->
    `04.hpv16_tree` and `05.hpv18_tree`.
- If mapping outputs contain multiple run IDs, tree steps may require explicit
  `bcf_run_id` in `config/analyses/targeted_analysis.config`.

## Current State Notes

- MultiQC configuration files are under `pipelines/multiqc/`.
- Tree images are at step root (`phylo_tree.svg/.png`), not inside
  `reports/`.
- Tree previews default to topology-depth scaling (branch lengths ignored)
  unless explicitly enabled.
- Run artifacts use repo-root cache directories (`.nextflow/`, `.conda/`).
- Downstream variant/VirStrain reporting currently excludes
  `Undetermined*` inputs.
- In report policy, mapping-vs-PAVE omits `General Statistics`, `Samtools`,
  and `Bcftools`; these are shown in variant-analysis reports.
- Metadata is organized in subdirectories:
  `metadata/bucketing`, `metadata/cohort`, `metadata/hpv16_tree`,
  `metadata/hpv18_tree`, and `metadata/seq_samples`.
- Reference snapshot directory: `reference-results/` (not tracked).

## Skills (technology procedures)

- Nextflow runtime env: `.agents/skills/nextflow/SKILL.md`
- Nextflow code authoring: `.agents/skills/nextflow-coding/SKILL.md`
- MultiQC config authoring: `.agents/skills/multiqc-config/SKILL.md`
- Analysis execution + troubleshooting:
  `.agents/skills/analysis-execution/SKILL.md`
- Phylogenetic tree operations:
  `.agents/skills/phylo-tree-operations/SKILL.md`
- Results summary authoring:
  `.agents/skills/results-summary/SKILL.md`

## References (human docs)

- Directory map: `docs/CONTENTS.md`
- Developer manual: `docs/developers/DEVELOPER_MANUAL.md`
- User manual: `docs/USER_MANUAL.md`

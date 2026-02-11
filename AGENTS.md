# Agent Runtime Rules (authoritative)

Read in order at task start:
1) `AGENTS.md`
2) `.agents/PROJECT.md`

## Non-negotiables

- Keep user-editable configuration under `config/`; step path configs live in
  `config/analyses/`.
- Move hardcoded values (for example sample IDs) to `metadata/`; do not
  hardcode them in scripts/pipelines.
- Never hardcode user-specific absolute paths (for example `/home/<user>`).
  Use PATH, env vars, or config params.
- Outputs policy:
  - Step outputs and non-MultiQC reports: `outs/<analysis>/<step>/...`
  - MultiQC HTML reports: `results/reports/<analysis>/...`
- When summarizing results, exclude controls/technical artifacts (`H2O`,
  `HPV-110`, `Ex`, `HPV-19`, and Illumina `Undetermined`) unless task is QC.
- For `METHODS_AND_RESULTS.md`, list `RunID:SampleID` when sample count is
  small (<=5, or <=10 if central) and keep prose-first style.
- Always create git commits for completed tasks; do not push.

## Verification Commands

- Whole analyses:
  - `bin/targeted_analysis.run.sh`
  - `bin/prelim_analysis.run.sh`
- Optional prelim VirStrain:
  - `bin/prelim_analysis.run.sh --run-virstrain`
- Step-level wrappers:
  - `bin/prelim_analysis.steps/*.run.sh`
  - `bin/targeted_analysis.steps/*.run.sh`
- Use the Nextflow runtime skill before any Nextflow execution:
  - `.agents/skills/nextflow/SKILL.md`

## Documentation Layering (guardrails)

- Runtime context (small, normative):
  - `AGENTS.md` (this file, authoritative rules)
  - `.agents/PROJECT.md` (compact project facts/policies)
- Reference-only (load on demand):
  - `.agents/WORKFLOW.md` (stable happy-path step order)
  - `.agents/skills/*/SKILL.md` (technology/task-specific procedures)
- Human docs (not runtime preload):
  - `docs/` (manuals, developer docs, notes)

## Anti-duplication Rules

- One source of truth per topic:
  - Behavior/rules: `AGENTS.md`
  - Project facts/current policies: `.agents/PROJECT.md`
  - Workflow order: `.agents/WORKFLOW.md`
  - Technology how-to: skill files under `.agents/skills/`
- Do not duplicate policies across files; use pointers instead.
- Add a new file only if information cannot fit an existing source-of-truth.
- Keep runtime agent docs small: target total size for `AGENTS.md` +
  `.agents/PROJECT.md` around 10-20 KB.

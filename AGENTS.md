- Read first: GOALS.md (assumptions) and INVENTORY.md (current steps/commands).
- CONTENTS.md lists directories only; do not list files; update it after any
  directory reordering.
- Keep configuration in `config/` under the repo root.
- Move hardcoded values (e.g., sample IDs) into `metadata/` and remove them from
  scripts.
- Never hardcode user-specific absolute paths (e.g., `/home/<user>`). Use PATH,
  env vars, or config options instead.
- When summarizing results, exclude controls / technical artifacts as defined in
  GOALS.md (e.g. `H2O`, `HVP-*`, and Illumina `Undetermined` reads) unless doing QC.
- When writing a `METHODS_AND_RESULTS.md`, list affected `RunID:SampleID` when only a few samples are involved (<=5, or <=10 if central), and keep results prose-first.
- Strict doc roles:
  - `SKILLS.md`: catalog of what exists (scope + where); no how-to.
  - `OPERATIONS.md`: runbook (how to run + troubleshoot) with concrete commands.
  - `WORKFLOWS.md`: happy-path step order and dependencies; no commands.
- Keep docs current when you change the repo: DECISIONS.md, OPERATIONS.md,
  PROMPTS.md, GOALS.md, CONTENTS.md, INVENTORY.md, SKILLS.md, WORKFLOWS.md.
- Always create git commits; do not push.
- You may run Nextflow to validate pipelines if needed.

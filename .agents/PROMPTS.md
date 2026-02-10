# PROMPTS

This file collects reusable prompt templates for common tasks in this repository.
Replace bracketed placeholders before use.

## Repo orientation
"""
Read AGENTS.md, .agents/INVENTORY.md, docs/CONTENTS.md, and .agents/SKILLS.md. Summarize the repo's current structure, active workflows, and any constraints that matter for edits.
"""

## Add or modify a pipeline step
"""
Update step [STEP_ID] in [prelim_analysis|targeted_analysis].
- Keep configuration in config/ and hardcoded data in metadata/.
- Do not hardcode user-specific absolute paths; rely on PATH/env/config.
- Update docs/CONTENTS.md and .agents/INVENTORY.md if the directory layout changes.
- Ensure outputs go under `outs/<analysis>/<step>/` and MultiQC reports under `results/reports/<analysis>/`.
- Keep `mapping_vs_pave` MultiQC focused on mapping/coverage summaries; keep `General Statistics` / `Samtools` / `Bcftools` sections in `variant_analysis` MultiQC.
- If the step is phylo_tree, keep tree images under `outs/<analysis>/<step>/` (not `reports/`) and ensure the MultiQC tree preview is embedded or otherwise resolvable offline.
- Provide a commit, do not push.
"""

## Fix a Nextflow pipeline error
"""
Investigate the failing Nextflow process [PROCESS_NAME].
- Compare the .nf implementation to any prior shell script if relevant.
- Identify the root cause and propose a minimal fix.
- Update tests or add validation where appropriate.
- Before rerunning, apply `.agents/skills/nextflow/SKILL.md` so the run uses the standard sandbox/offline environment variables.
- Ensure no runtime cache/env is created under `pipelines/.conda`; wrapper-driven runs must use repo-root `.conda`.
"""

## Add a new metadata list
"""
Create or update metadata in metadata/ for [INPUT_NAME].
- Wire it into the relevant scripts/pipelines.
- Avoid hardcoding sample IDs in scripts.
- Update .agents/INVENTORY.md if the metadata list is new.
"""

## Compare outputs between analyses
"""
Compare outputs between [ANALYSIS_A] and [ANALYSIS_B].
- Focus on reports/ outputs first.
- Summarize differences with file and row-level highlights.
- When computing prevalence/proportions, exclude controls / technical artifacts
  (HPV-19, HPV-110, Ex, H2O, Undetermined) unless explicitly requested.
"""

## Move or rename analysis directories
"""
Rename or move analysis directories to [NEW_LAYOUT].
- Update docs/CONTENTS.md and .agents/INVENTORY.md.
- Fix references in scripts, configs, and docs.
- Commit changes without pushing.
"""

## Add documentation
"""
Create [DOC_NAME].md describing [TOPIC].
- Keep it concise and aligned with AGENTS.md constraints.
- Include paths and expected outputs.
"""

## Create a METHODS_AND_RESULTS summary (human-readable)
"""
Create or update [prelim_analysis|targeted_analysis]/METHODS_AND_RESULTS.md for step [STEP_ID].

Constraints:
- Use the same procedural description as the step MultiQC report Methods section, but written in
  scientific prose (avoid listing script names/filenames unless essential for reproducibility).
- Exclude controls / technical artifacts from prevalence/proportion statements unless explicitly doing QC
  (H2O, HPV-110, HPV-19, Ex, and Illumina Undetermined/unassigned reads).
- Summarize results as narrative text with key proportions and ranges; use binning only to support the text.
- Whenever you mention a small number of samples, list them as `RunID:SampleID`:
  - If count <= 5: always list.
  - If the statement is critical/central and count <= 10: list.
- State the exact report tables used (paths under the step `reports/`) and whether values come from
  human-excluded or inclusive tables.
"""

# PROMPTS

This file collects reusable prompt templates for common tasks in this repository.
Replace bracketed placeholders before use.

## Repo orientation
"""
Read AGENTS.md, GOALS.md, INVENTORY.md, CONTENTS.md, and SKILLS.md. Summarize the repo's current structure, active workflows, and any constraints that matter for edits.
"""

## Add or modify a pipeline step
"""
Update step [STEP_ID] in [analysis-input1|analysis-input2].
- Keep configuration in config/ and hardcoded data in metadata/.
- Do not hardcode user-specific absolute paths; rely on PATH/env/config.
- Update CONTENTS.md and INVENTORY.md if the directory layout changes.
- Provide a commit, do not push.
"""

## Fix a Nextflow pipeline error
"""
Investigate the failing Nextflow process [PROCESS_NAME].
- Compare the .nf implementation to any prior shell script if relevant.
- Identify the root cause and propose a minimal fix.
- Update tests or add validation where appropriate.
"""

## Add a new metadata list
"""
Create or update metadata in metadata/ for [INPUT_NAME].
- Wire it into the relevant scripts/pipelines.
- Avoid hardcoding sample IDs in scripts.
- Update INVENTORY.md if the metadata list is new.
"""

## Compare outputs between analyses
"""
Compare outputs between [ANALYSIS_A] and [ANALYSIS_B].
- Focus on reports/ outputs first.
- Summarize differences with file and row-level highlights.
- When computing prevalence/proportions, exclude controls / technical artifacts
  defined in GOALS.md unless explicitly requested.
"""

## Move or rename analysis directories
"""
Rename or move analysis directories to [NEW_LAYOUT].
- Update CONTENTS.md and INVENTORY.md.
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
Create or update [analysis-input1|analysis-input2]/METHODS_AND_RESULTS.md for step [STEP_ID].

Constraints:
- Use the same procedural description as the step MultiQC report Methods section, but written in
  scientific prose (avoid listing script names/filenames unless essential for reproducibility).
- Exclude controls / technical artifacts from prevalence/proportion statements unless explicitly doing QC
  (see GOALS.md: H2O, HVP-*, and Illumina Undetermined/unassigned reads).
- Summarize results as narrative text with key proportions and ranges; use binning only to support the text.
- Whenever you mention a small number of samples, list them as `RunID:SampleID`:
  - If count <= 5: always list.
  - If the statement is critical/central and count <= 10: list.
- State the exact report tables used (paths under the step `reports/`) and whether values come from
  human-excluded or inclusive tables.
"""

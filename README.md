# Kh_HIVp_HPV

## Purpose

This repository consolidates and cleans up multi-year HPV/HIV pipeline work into a reproducible layout.
It centralizes scripts and Nextflow pipelines, moves hardcoded values into `metadata/`, and keeps
configuration in `config/` so analyses can be rerun consistently.

## How to run the analyses

Use `WORKFLOWS.md` for the step order and dependencies, and `OPERATIONS.md` for the exact commands.
Each step writes to its own `output/` and `reports/` directory, so you can start/stop at any step
by running only the steps you need and reusing existing outputs.

### analysis-input1 (full analysis)

Happy-path steps:
1) 001.0.centrifuge — bucketing
2) 002.0.bowtie_vs_pave — mapping vs PAVE
3) 003.0.virstrain — VirStrain reports
4) 004.0.bowtie_vs_pave.E6 — E6 mapping
5) 005.0.bowtie_vs_pave.E7 — E7 mapping

Start/stop at a single step:
- Run the step you want using the commands in `OPERATIONS.md`.
- If a step depends on earlier outputs (e.g., bucketing), ensure the required `output/` directories
  already exist before running that step.

### analysis-input2 (mapping + phylogenetic trees)

Happy-path steps:
1) 001.0.bucketing — bucketing
2) 002.0.mapping_vs_pave — mapping vs PAVE
3) 003.0.hpv16_tree — HPV16 tree (requires prepared inputs under `input/`)
4) 004.0.hpv18_tree — HPV18 tree (requires prepared inputs under `input/`)

Start/stop at a single step:
- Run the step you want using the commands in `OPERATIONS.md`.
- Tree steps depend on prepared inputs in each tree step’s `input/` directory and (for consensus
  sequences) on mapping outputs from step 002.

## Reference snapshots

If you need a frozen copy of outputs for regression checks, use the snapshot procedure documented
in `OPERATIONS.md` (it populates the `reference-results/` directory, which is gitignored).

## Related docs

- `SKILLS.md`: what exists (scope + where)
- `WORKFLOWS.md`: happy-path sequence of steps and dependencies
- `OPERATIONS.md`: run commands and troubleshooting
- `INVENTORY.md`: current steps/scripts and manual commands

# DECISIONS

This log records notable decisions made for this repository.
Format:
- Date (YYYY-MM-DD): Decision
  - Context:
  - Decision:
  - Rationale:
  - Consequences:

## Decisions

- 2026-01-24: Consolidate analyses into analysis-input1 and analysis-input2
  - Context: analysis-1 and analysis-2 overlapped; analysis-3 needed a stable final name.
  - Decision: merge analysis-1/analysis-2 into analysis-input1 and rename analysis-3 to analysis-input2.
  - Rationale: simplify layout, reduce duplication, and align with GOALS.md.
  - Consequences: update references, inventories, and defaults to use analysis-input1/2.

- 2026-01-24: Centralize configuration and metadata
  - Context: scripts contained hardcoded paths and sample lists.
  - Decision: keep configuration in config/ and hardcoded data in metadata/.
  - Rationale: improve reuse and reduce step-specific edits.
  - Consequences: pipelines/scripts must read config/metadata and avoid inline literals.

---
name: multiqc-config-authoring
description: Repository-specific guide for writing and updating MultiQC YAML configs, including custom sections, table wiring, compound IDs, section ordering, and common failure prevention.
---

# MultiQC Config Authoring

Use this skill whenever editing:
- `pipelines/multiqc/*.multiqc.yml`
- MultiQC-related table-prep scripts under `scripts/*/prepare_*multiqc*.py`
- Nextflow MultiQC processes that stage report inputs.

## Repo Contract

- MultiQC configs live in `pipelines/multiqc/`.
- Non-MultiQC step outputs live in `outs/<analysis>/<step>/`.
- MultiQC HTML reports are published to `results/reports/<analysis>/`.
- MultiQC helper tables (`*.multiqc.tsv`) are step reports and must live in
  `outs/<analysis>/<step>/reports/` (not in `results/`).

## Config Structure (required patterns)

Keep this structure in each YAML:

1. `title`
2. `custom_data` entries for:
   - `methods_summary` (`plot_type: html`) with tool citations
   - `output_locations` (`plot_type: html`)
   - `reports_tables` (`plot_type: html`)
3. Table sections (`plot_type: table`) with explicit `section_name`,
   `description`, and `pconfig.col1_header`.
4. `sp` mappings for each table key to `fn: "<name>.multiqc.tsv"`.

Minimal table example:

```yaml
custom_data:
  example_table:
    file_format: "tsv"
    section_name: "Example"
    description: "Example table"
    plot_type: "table"
    pconfig:
      col1_header: "Sample"
sp:
  example_table:
    fn: "example.multiqc.tsv"
```

## Custom Content: When and How

Add custom HTML sections when users need context without reading scripts:
- method summary
- output paths
- which tables are generated
- optional inline preview blocks (for example phylo tree preview).

Rules:
- Keep prose short and procedural.
- Include primary references for core tools in method summaries.
- Do not duplicate pipeline internals that will drift quickly.

## Compound IDs in Tables: When, Why, How

### When necessary

Use compound IDs in the first column whenever sample names can collide:
- same sample IDs across multiple run IDs
- multiple strain/gene/variant rows per sample
- merged inputs from multiple directories.

### Why

MultiQC tables key rows by first column (`Sample` by default). Non-unique IDs
cause ambiguity and can collapse or overwrite logical entities in the report.

### How

Prepend a synthetic first column when generating `*.multiqc.tsv`:
- basic: `run_id:sample_id`
- per-strain rows: `run_id:sample_id:strain`
- per-variant rows: `run_id:sample_id:strain:gene:mutation`

This is the repository standard used by:
- `scripts/taxonomy_assignment/prepare_centrifuge_multiqc_inputs.py`
- `scripts/coverage/prepare_bowtie_multiqc_inputs.py`
- `scripts/coverage/prepare_pave_multiqc_inputs.py`
- `scripts/variants/prepare_variant_multiqc_inputs.py`
- `scripts/virstrain/prepare_virstrain_multiqc_inputs.py`

## Section Ordering and Module Policy

- Use `module_order` / `section_order` when deterministic ordering matters.
- In variant-analysis reports, keep `general_stats`, `Samtools`, and
  `bcftools` at the bottom (via config ordering and, when needed,
  `scripts/variants/reorder_multiqc_sections.py`).
- In mapping-vs-PAVE reports, these sections are intentionally omitted.

## Collision and Staging Safety

Avoid Nextflow file-collision failures in MultiQC processes:
- Do not stage identically named files from different run dirs into one flat
  input channel.
- Build a local staged tree in the process script (`mapping_qc/<run_id>/...`)
  before running MultiQC.
- Exclude technical artifacts (`Undetermined*`) in downstream reports where
  collisions are common and not analytically relevant.

## Troubleshooting Checklist

1. Section not shown:
   - `sp` key mismatch between `custom_data` and `sp`
   - wrong `fn` pattern or file not generated.
2. Table empty:
   - malformed TSV header
   - wrong delimiter
   - preprocess script wrote no rows.
3. Wrong output location:
   - MultiQC process publishing to step `reports/` instead of
     `results/reports/<analysis>/`.
4. `unknown_analysis` or `null` paths:
   - missing `analysis_name` / `step_name` parameter wiring in pipeline config.
5. Filename collision failure:
   - duplicate basenames staged from multiple run directories.

## Validation Before Commit

1. Confirm expected `*.multiqc.tsv` files exist under step `reports/`.
2. Confirm report exists at `results/reports/<analysis>/<step>.report.html`.
3. Grep report HTML for expected section titles.
4. For collision-prone datasets, verify compound IDs are unique.
5. Confirm policy consistency:
   - mapping-vs-PAVE hides general stats modules
   - variant-analysis includes them at the bottom.

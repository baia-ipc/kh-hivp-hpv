# DECISIONS

This log records notable decisions made for this repository.
Format:
- Date (YYYY-MM-DD): Decision
  - Context:
  - Decision:
  - Rationale:
  - Consequences:

## Decisions

- 2026-02-11: Exclude Undetermined samples from variant-analysis and downstream VirStrain reporting
  - Context: prelim step 03 MultiQC failed due staged input filename collisions from multiple `Undetermined.*` mapping QC files across run directories.
  - Decision: stop staging mapping QC files through channels in `pipelines/variant_analysis.nf`; instead build a local `mapping_qc/` view at MultiQC time that skips `Undetermined*` samples. Also filter `Undetermined*` samples in `pipelines/virstrain.nf` sample selection.
  - Rationale: avoids Nextflow input-file name collisions and keeps technical artifacts out of downstream reporting.
  - Consequences: prelim step 03 no longer fails on `Undetermined` collisions; prelim step 04 VirStrain excludes `Undetermined` buckets by default.

- 2026-02-10: Use adaptive multi-ring labels for circular phylogenetic previews
  - Context: single-ring circular labels became unreadable and overlapped for dense HPV16/HPV18 trees.
  - Decision: update `scripts/phylo_tree/render_tree_svg.py` to use deterministic circular tip spacing, topology-scaled radii, adaptive multi-ring label placement, and default label truncation.
  - Rationale: improve offline readability of tree labels while keeping a circular layout suitable for MultiQC embedding.
  - Consequences: tree previews are easier to read in dense trees; users can still override label behavior with `--label-fontsize` and `--max-label-chars`.

- 2026-02-10: Force wrapper-based Nextflow runs to use repo-root Conda caches
  - Context: a stray `pipelines/.conda/` appeared, indicating some runs resolved Conda cache paths under the pipeline directory instead of repo root.
  - Decision: make `bin/run_step.py` normalize `NXF_HOME`, `CONDA_ENVS_PATH`, and `CONDA_PKGS_DIRS` to repo-root paths and override any values pointing under `pipelines/.conda`.
  - Rationale: prevent environment/cache creation under `pipelines/` and keep all runtime caches in one predictable location.
  - Consequences: wrapper-driven runs now self-heal misconfigured env vars and avoid recreating `pipelines/.conda`.

- 2026-02-10: Render phylogenetic tree previews without branch-length scaling by default
  - Context: distant outgroups caused circular tree previews to be skewed and compressed the ingroup structure.
  - Decision: change `scripts/phylo_tree/render_tree_svg.py` to ignore branch lengths by default (topology depth rendering), with an explicit opt-in flag to use real branch lengths.
  - Rationale: improves readability of offline tree previews in MultiQC when outgroups are much more divergent than target sequences.
  - Consequences: `pipelines/phylo_tree.nf` exposes `params.tree_use_branch_lengths` (default `false`) and phylo-tree docs now describe topology-based rendering.

- 2026-02-10: Publish phylogenetic tree images under step outdir and embed previews in MultiQC
  - Context: tree SVG/PNG were being written under `outs/<analysis>/<step>/reports/`, and the MultiQC HTML preview referenced `phylo_tree.svg` without a reliable step-specific asset path.
  - Decision: publish tree images to `outs/<analysis>/<step>/` (step root), embed the step SVG directly in each MultiQC report after generation, and switch rendering to circular layout by default.
  - Rationale: keep tree artifacts in the step output root and ensure offline tree previews render reliably in `results/reports/<analysis>/` without cross-step filename collisions.
  - Consequences: updated `pipelines/phylo_tree.nf`, `pipelines/multiqc/phylo_tree.multiqc.yml`, and `scripts/phylo_tree/render_tree_svg.py`.

- 2026-02-05: Organize metadata into subdirectories
  - Context: metadata files lived flat under `metadata/`, making it harder to locate related assets.
  - Decision: group bucketing, cohort, tree inputs, and sample sheets into subdirectories under `metadata/`.
  - Rationale: improve discoverability and keep related metadata together.
  - Consequences: update configs, pipelines, scripts, and documentation to use new paths.

- 2026-02-05: Consolidate step wrappers with a generic runner
  - Context: per-step `bin/*.steps/*.run.sh` scripts duplicated Nextflow invocation logic.
  - Decision: add a generic runner (`bin/run_step.py`) and JSON step configs under `config/steps/`, keeping the per-step wrappers as thin shims.
  - Rationale: reduce duplication and centralize runner logic while preserving existing entry points.
  - Consequences: update docs and inventories to reference the generic runner and JSON configs.

- 2026-02-05: Align lineage reference handling across HPV16 and HPV18 trees
  - Context: HPV18 lineage assignment had a reference-tip list and helper script, but HPV16 lacked the equivalent assets.
  - Decision: add `metadata/hpv16_tree/hpv16_lineage_refs.tsv` and a generic `scripts/phylo_tree/assign_lineages.py` helper for lineage assignment.
  - Rationale: keep lineage annotation workflows consistent across HPV16 and HPV18.
  - Consequences: update inventories and documentation to mention the new HPV16 lineage refs and helper.

- 2026-02-04: Move analysis outputs to `outs/` and track curated results under `results/`
  - Context: analysis outputs and reports were stored under analysis directories, and MultiQC reports lived alongside other reports.
  - Decision: write outputs and non‑MultiQC reports under `outs/<analysis>/<step>/`, store MultiQC reports under `results/reports/<analysis>/`, and keep curated results tracked in git under `results/` while ignoring raw analysis outputs.
  - Rationale: separate large run artifacts from tracked outputs and standardize report locations.
  - Consequences: update configs, pipelines, scripts, and documentation; migrate existing outputs into `outs/` and `results/`.

- 2026-02-04: Derive NCBI selection TSVs from metadata accession lists
  - Context: tree selection lists moved out of `refdata/`, and selection TSVs should be derived consistently for HPV16/HPV18.
  - Decision: store accession lists in `metadata/hpv16_tree/hpv16_tree_db_selection.txt` and `metadata/hpv18_tree/hpv18_tree_db_selection.txt`, and derive the selection TSVs in the phylo tree pipeline.
  - Rationale: keep user-editable selections in metadata and generate consistent derived inputs.
  - Consequences: add a selection-build script, update phylo tree configs/pipeline, and update documentation references.

- 2026-02-04: Add offline tree visualization + MultiQC tree summary stats
  - Context: tree construction steps relied on step-local READMEs for manual guidance and MultiQC lacked tree previews and intermediate statistics.
  - Decision: move tree reference acquisition instructions to the user manual, remove step README files, and extend the phylo tree pipeline to render offline tree images and emit summary stats for MultiQC.
  - Rationale: keep user-facing instructions centralized and make tree outputs self-contained in the MultiQC report.
  - Consequences: new tree rendering/stats scripts, updated phylo tree pipeline and MultiQC config, and a Biopython dependency in the pipeline env.

- 2026-02-03: Split mapping vs variant analysis steps and align step naming across analyses
  - Context: variant aggregation and database comparison were bundled with mapping in step 02, and prelim_analysis step names differed from targeted_analysis.
  - Decision: keep step 02 as mapping-only (`mapping_vs_pave`), add step 03 `variant_analysis` in both analyses (targeted step 03 also runs database SNP comparison), renumber HPV tree steps to 04/05, and rename prelim_analysis steps to `bucketing` and `mapping_vs_pave`.
  - Rationale: isolate variant analysis and keep step naming consistent across analyses.
  - Consequences: new pipeline `pipelines/variant_analysis.nf`, updated wrappers/configs/docs, and new step outputs under `*/03.variant_analysis`.

- 2026-02-03: Rename intermediate_files to derived_data and consolidate indices
  - Context: intermediate assets mixed derived refdata and reusable indices across analysis outputs.
  - Decision: rename `intermediate_files/` to `derived_data/`, and share the Bowtie/PAVE index under `derived_data/indices/bowtie_vs_pave`.
  - Rationale: clarify that the data are derived and reduce duplicated indices between analyses.
  - Consequences: update configs/docs to use `derived_data/` paths and move HPV16/HPV18 reference FASTAs to `refdata/`.

- 2026-02-03: Derive Nextflow concurrency from wrapper args
  - Context: Nextflow config validation rejects `params.threads` references inside `config/pipelines/*.config` on this system.
  - Decision: remove `params.threads` from pipeline configs and have wrapper scripts pass `-process.maxForks`, `-executor.queueSize`, and `-process.cpus` based on `config/user.config`.
  - Rationale: keep user-level control in `params.threads` without invalid config attributes.
  - Consequences: wrappers must read `threads` from `config/user.config` before running Nextflow.

- 2026-01-24: Add reference snapshot directory
  - Context: need to compare old results vs updated pipelines.
  - Decision: store a copy of outputs/reports/indexes under `reference-results/` and ignore it in git.
  - Rationale: enable regression checks without altering tracked outputs.
  - Consequences: refresh the snapshot when results change.

- 2026-01-27: Cap Nextflow concurrency by default
  - Context: running many tasks at once can overload shared nodes.
  - Decision: set `process.maxForks = 24` and `executor.queueSize = 24` in step config files under `config/`.
  - Rationale: keep default runs bounded while still parallel.
  - Consequences: adjust the cap in config files when running on larger systems.

- 2026-01-27: Use metadata sample IDs for multi-sample bucketing
  - Context: legacy centrifuge outputs are named after the sample IDs listed in metadata, not the normalized FASTQ filenames.
  - Decision: set the sample ID in `pipelines/centrifuge_bucketing_all.nf` from the metadata sample column.
  - Rationale: keep `--skip-align` compatible with precomputed alignment/report files and historical naming.
  - Consequences: alignment/report filenames follow metadata sample IDs for multi-sample runs.

- 2026-02-02: Centralize Conda environment definitions under pipelines
  - Context: pipeline env files were mixed with other config in `config/`.
  - Decision: move all `*.env.yml` to `pipelines/conda_env/` and update references.
  - Rationale: keep pipeline runtime environments alongside the workflows that consume them.
  - Consequences: configs and docs must reference `pipelines/conda_env/*` for Conda envs.

- 2026-02-02: Split user vs technical Nextflow configuration
  - Context: pipeline configs mixed user-editable parameters with executor/conda wiring, and step paths lived in wrappers.
  - Decision: keep user-editable configs in `config/`, move technical Nextflow settings to `config/pipelines/`, and add step-specific config files for inputs/outputs.
  - Rationale: ensure users only edit `config/` while keeping technical defaults centralized.
  - Consequences: wrappers pass multiple `-c` files; new step configs define `outdir`, `reports_dir`, and inputs.

- 2026-02-02: Relocate MultiQC configs alongside pipelines
  - Context: MultiQC configs were mixed into `config/` with user-editable settings.
  - Decision: move `*.multiqc.yml` into `pipelines/multiqc/` and update references.
  - Rationale: keep pipeline-owned config with pipeline assets while leaving `config/` for user edits.
  - Consequences: technical configs and pipelines reference `pipelines/multiqc/*`.

- 2026-02-02: Consolidate user config into `config/user.config`
  - Context: user parameters were split across multiple `config/*.config` files.
  - Decision: move all user-editable parameters into a single `config/user.config`.
  - Rationale: keep user configuration in one place and set shared defaults (e.g., `threads`) only once.
  - Consequences: wrappers and docs reference `config/user.config`; per-pipeline user configs are removed.

- 2026-02-03: Merge database comparison into variant analysis pipeline
  - Context: targeted step 03 ran a separate database SNP pipeline after variant analysis.
  - Decision: fold database comparison into `pipelines/variant_analysis.nf` behind `include_database`, enabled by default in the targeted profile and disabled in prelim.
  - Rationale: simplify step 03 execution and keep all outputs within a single pipeline run.
  - Consequences: remove `pipelines/database_snps.nf` and its config, update wrappers/docs, and extend `variant_analysis` config and workflow.

- 2026-02-03: Make phylogenetic tree inputs fully derived
  - Context: tree preparation required manual commands and checked derived inputs into git.
  - Decision: move curated selection lists into `refdata/`, generate all derived tree inputs in `pipelines/phylo_tree.nf`, and ignore `derived_data/` in git.
  - Rationale: eliminate manual steps and keep derived assets out of version control.
  - Consequences: update phylo tree configs, scripts, and documentation; remove tracked `derived_data/` contents.

- 2026-02-05: Move embedded pipeline Python into scripts
  - Context: Nextflow pipelines embedded large Python here-docs for MultiQC table preparation, which made the pipelines hard to read.
  - Decision: extract Python logic into dedicated scripts under `scripts/` and call them from the pipelines.
  - Rationale: keep pipeline definitions readable and centralize reusable logic.
  - Consequences: add new helper scripts for MultiQC table preparation and update the affected pipelines to call them.

- 2026-02-06: Use VirStrain-specific conda env for the virstrain pipeline
  - Context: `pipelines/virstrain.nf` ran without a conda directive and defaulted to the general pipeline env config.
  - Decision: configure VirStrain steps to use `pipelines/conda_env/virstrain.env.yml` and run MultiQC with the prebuilt pipeline env.
  - Rationale: keep VirStrain dependencies isolated while avoiding offline conda downloads for MultiQC.
  - Consequences: update `config/pipelines/virstrain.config` and add conda directives to virstrain processes.

- 2026-02-10: Move SAMtools/Bcftools sections from mapping MultiQC to variant MultiQC
  - Context: mapping-vs-PAVE reports included `General Statistics`, `Samtools`, and `Bcftools` sections, while variant reports lacked those low-level QC views.
  - Decision: disable `General Statistics`, `Samtools`, and `Bcftools` in `pipelines/multiqc/bowtie_vs_pave.multiqc.yml`, and include mapping `*.idxstats`/`*.bcf.vchk` files in variant MultiQC inputs (`pipelines/variant_analysis.nf`), ordering these sections at the bottom in variant MultiQC configs.
  - Rationale: keep mapping reports focused on strain/coverage summaries and centralize alignment/variant-call QC sections in variant analysis.
  - Consequences: update `pipelines/multiqc/bowtie_vs_pave.multiqc.yml`, `pipelines/multiqc/variant_analysis.multiqc.yml`, `pipelines/multiqc/variant_analysis_db.multiqc.yml`, and `pipelines/variant_analysis.nf`.

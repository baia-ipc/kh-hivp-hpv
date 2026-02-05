# OPERATIONS

Runbook with concrete commands and fixes (how to run + troubleshoot).

Rules:
- Put runnable commands and troubleshooting here.
- Do not turn this into a catalog (keep that in `.agents/SKILLS.md`) or an ordered workflow spec (keep that in `.agents/WORKFLOWS.md`).

## Conventions

- User-editable configuration is in `config/`; step path configs are under `config/analyses/`; technical Nextflow config is in `config/pipelines/`. Sample lists live in `metadata/`.
- Raw reference inputs live in `refdata/`; derived reference assets live in `derived_data/refdata/`.
- Outputs are written under `outs/<analysis>/<step>/` with non‑MultiQC reports under `outs/<analysis>/<step>/reports/`.
- When changing directory layout, update `CONTENTS.md` and `.agents/INVENTORY.md`.
- Avoid user-specific absolute paths in scripts; require tools via PATH or
  configurable env vars (e.g., `CONDA_EXE`).
- Default parallelism is tied to `params.threads` (from `config/user.config`) via wrapper-provided `-process.maxForks` and `-executor.queueSize`.
- Step wrappers read `params.threads` from `config/user.config` and pass it as `-process.maxForks`, `-executor.queueSize`, and `-process.cpus` to Nextflow.
- MultiQC reports are written under `results/reports/<analysis>/`. Ensure the MultiQC process outputs files at the process root and publish to the `results/reports` target to avoid duplicated `multiqc/multiqc_report.html` paths.
- MultiQC method summaries should cite the primary tool papers; update the relevant `pipelines/multiqc/*.multiqc.yml` when pipeline steps change.
- MultiQC custom sections should be configured under `custom_data` with explicit `plot_type` and any table inputs connected via `sp:` search patterns in the same config.
- Curated outputs can be copied under `results/` for sharing or downstream review (tracked in git).

## Running pipelines

### Wrapper scripts (bin/)

Run whole analyses:

```
bin/prelim_analysis.run.sh
bin/targeted_analysis.run.sh
```

VirStrain is optional for prelim_analysis; run it with:

```
bin/prelim_analysis.run.sh --run-virstrain
```

Run individual steps (all samples):

```
bin/prelim_analysis.steps/01.bucketing.run.sh
bin/targeted_analysis.steps/02.mapping_vs_pave.run.sh
```

Run a single sample (for steps that support it):

```
bin/targeted_analysis.steps/single_sample/02.mapping_vs_pave.run_sample.sh
```

### prelim_analysis bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/centrifuge_bucketing.config \
  -c config/user.config \
  -c config/analyses/prelim_analysis.config \
  -profile preliminary_bucketing \
  -resume
```

MultiQC report is written to `results/reports/prelim_analysis/01_bucketing.report.html`.

### Build the Centrifuge database (human + RefSeq archaea/bacteria/viral)

- Build the index and taxonomy under `refdata/centrifuge/`:
```
scripts/taxonomy_assignment/build_centrifuge_db.sh --outdir refdata/centrifuge --index-name human_abv --threads 24
```

- Point `config/user.config` to the resulting paths, for example:
- `index = "refdata/centrifuge/human_abv"`
  - `taxdump = "refdata/centrifuge/taxonomy-YYYY-MM-DD"`

### targeted_analysis bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/centrifuge_bucketing.config \
  -c config/user.config \
  -c config/analyses/targeted_analysis.config \
  -profile targeted_bucketing \
  -resume
```

### Mapping vs PAVE (Nextflow)

- prelim_analysis:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/bowtie_vs_pave.config \
  -c config/user.config \
  -c config/analyses/prelim_analysis.config \
  -profile preliminary_mapping_vs_pave \
  -resume
```

- targeted_analysis:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/bowtie_vs_pave.config \
  -c config/user.config \
  -c config/analyses/targeted_analysis.config \
  -profile targeted_mapping_vs_pave \
  -resume
```

### Variant analysis (Nextflow)

- prelim_analysis:

```
nextflow run pipelines/variant_analysis.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/variant_analysis.config \
  -c config/user.config \
  -c config/analyses/prelim_analysis.config \
  -profile preliminary_variant_analysis \
  -resume
```

- targeted_analysis:

```
nextflow run pipelines/variant_analysis.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/variant_analysis.config \
  -c config/user.config \
  -c config/analyses/targeted_analysis.config \
  -profile targeted_variant_analysis \
  -resume
```
Database comparison is enabled by default in the targeted profile. To skip it when using the wrapper, pass `--skip-database` (the report will use the base MultiQC config and omit database tables).

### VirStrain reports (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/virstrain.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/virstrain.config \
  -c config/user.config \
  -c config/analyses/prelim_analysis.config \
  -profile preliminary_virstrain \
  --run-virstrain \
  -resume
```

### HPV16 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/phylo_tree.config \
  -c config/pipelines/phylo_tree.hpv16.config \
  -c config/user.config \
  -c config/analyses/targeted_analysis.config \
  -profile targeted_hpv16_tree \
  -resume
```

This pipeline derives any missing/out-of-date inputs under `derived_data/refdata/hpv16_tree` from `refdata/hpv16_tree` and mapping outputs.
Tree reports include `reports/phylo_tree.svg` (PNG fallback) and `reports/phylo_tree_summary.multiqc.tsv`.

### HPV18 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/phylo_tree.config \
  -c config/pipelines/phylo_tree.hpv18.config \
  -c config/user.config \
  -c config/analyses/targeted_analysis.config \
  -profile targeted_hpv18_tree \
  -resume
```

This pipeline derives any missing/out-of-date inputs under `derived_data/refdata/hpv18_tree` from `refdata/hpv18_tree` and mapping outputs.
Tree reports include `reports/phylo_tree.svg` (PNG fallback) and `reports/phylo_tree_summary.multiqc.tsv`.

### Generate PAVE feature tables (derived)

Coverage statistics use feature tables derived from the PAVE GFF3 files.
Generate them under `derived_data/refdata/pave/features_tsv` with:

```
scripts/pave/gff3_to_features_tsv.run_all.sh \
  refdata/pave/gff3 \
  derived_data/refdata/pave/features_tsv
```

### Generate PAVE BED files (derived)

E6/E7 SNP extraction relies on BED intervals derived from the same PAVE GFF3s.
Generate them under `derived_data/refdata/pave/bed` with:

```
scripts/pave/gff3_to_bed.run_all.sh \
  refdata/pave/gff3 \
  derived_data/refdata/pave/bed
```

## Reruns and resume

- Nextflow: use `-resume` to reuse successful tasks.
- Scripts: remove a step's `outs/<analysis>/<step>/` to force a full rerun.

## Troubleshooting

- Check `.nextflow.log` for pipeline errors.
- Inspect process work directories under `work/` and read `.command.sh`, `.command.err`, `.command.out`.
- If tools are missing, confirm the Conda env file under `pipelines/conda_env/` is referenced by the matching `config/pipelines/*.config`.
- Nextflow requires Java 17+; if Conda provides an older Java, use the env in `pipelines/conda_env/nextflow_java.env.yml`:
- When adding a new Nextflow parameter in a pipeline (e.g. `params.multiqc_config`), also add it to `config/user.config` (user) or the matching `config/pipelines/*.config` (technical) file to avoid “undefined parameter” warnings.

```
conda env create -f pipelines/conda_env/nextflow_java.env.yml
conda activate nextflow-java
```

If you do not want to activate any env, run with explicit Java (and optionally disable conda's CUDA probing if `conda info --json` fails):

```
CONDA_OVERRIDE_CUDA=0 \
JAVA_CMD=/usr/lib/jvm/java-21-openjdk-amd64/bin/java \
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
nextflow run <pipeline> -c <config> -resume
```

If the node has no network access, also set:

```
NXF_HOME=/home/$USER/.nextflow \
NXF_OFFLINE=true \
```

## Reference snapshots

To refresh the reference snapshot used for regression checks:

```
mkdir -p reference-results
for step in outs/prelim_analysis/* outs/targeted_analysis/*; do
  [ -d "$step" ] || continue
  dest="reference-results/$step"
  mkdir -p "$dest"
  cp -a "$step/." "$dest/"
done

if [ -d derived_data/indices ]; then
  mkdir -p reference-results/derived_data/indices
  cp -a derived_data/indices/. reference-results/derived_data/indices/
fi
```

## Updating inputs

- Update sample lists in `metadata/`.
- Ensure reference indices exist under `derived_data/indices/` (Bowtie/VirStrain) and raw reference inputs under `refdata/`.

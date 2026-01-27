# OPERATIONS

Runbook with concrete commands and fixes (how to run + troubleshoot).

Rules:
- Put runnable commands and troubleshooting here.
- Do not turn this into a catalog (keep that in `SKILLS.md`) or an ordered workflow spec (keep that in `WORKFLOWS.md`).

## Conventions

- Configuration is in `config/` and sample lists in `metadata/`.
- Outputs are written to each step's `output/` and `reports/`.
- When changing directory layout, update `CONTENTS.md` and `INVENTORY.md`.
- Default parallelism is capped at 24 concurrent tasks via `process.maxForks` and `executor.queueSize` in the step config files under `config/`.
- MultiQC reports are written under each step's `reports/multiqc/` (phylo tree steps use `output/reports/multiqc/`). Ensure the MultiQC process outputs files at the process root and publish to `reports/multiqc/` to avoid duplicated `multiqc/multiqc_report.html` paths.

## Running pipelines

### analysis-input1 bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/centrifuge_bucketing.config \
  -resume

MultiQC report is written to `analysis-input1/001.0.centrifuge/reports/multiqc/`.
```

### analysis-input2 bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/centrifuge_bucketing.config \
  --samples_tsv metadata/samples-input2.tsv \
  --outdir analysis-input2/001.0.bucketing/output \
  --reports_dir analysis-input2/001.0.bucketing/reports \
  -resume
```

### Bowtie vs PAVE mapping (Nextflow)

- analysis-input1:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/bowtie_vs_pave.config \
  --reads_dir analysis-input1/001.0.centrifuge/output \
  --outdir analysis-input1/002.0.bowtie_vs_pave/output \
  --reports_dir analysis-input1/002.0.bowtie_vs_pave/reports \
  --index_dir analysis-input1/002.0.bowtie_vs_pave/index \
  -resume
```

- analysis-input2:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/bowtie_vs_pave.config \
  --reads_dir analysis-input2/001.0.bucketing/output \
  --outdir analysis-input2/002.0.mapping_vs_pave/output \
  --reports_dir analysis-input2/002.0.mapping_vs_pave/reports \
  --index_dir analysis-input2/002.0.mapping_vs_pave/index \
  -resume
```

### VirStrain reports (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/virstrain.nf \
  -c config/virstrain.config \
  --reads_dir analysis-input1/001.0.centrifuge/output \
  --outdir analysis-input1/003.0.virstrain/output \
  --reports_dir analysis-input1/003.0.virstrain/reports \
  --index_dir analysis-input1/003.0.virstrain/index \
  -resume
```

### PAVE E6 mapping (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/pave_gene_mapping.nf \
  -c config/pave_e6.config \
  --reads_dir analysis-input1/001.0.centrifuge/output \
  --outdir analysis-input1/004.0.bowtie_vs_pave.E6/output \
  --reports_dir analysis-input1/004.0.bowtie_vs_pave.E6/reports \
  --index_dir analysis-input1/004.0.bowtie_vs_pave.E6/index \
  -resume
```

### PAVE E7 mapping (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/pave_gene_mapping.nf \
  -c config/pave_e7.config \
  --reads_dir analysis-input1/001.0.centrifuge/output \
  --outdir analysis-input1/005.0.bowtie_vs_pave.E7/output \
  --reports_dir analysis-input1/005.0.bowtie_vs_pave.E7/reports \
  --index_dir analysis-input1/005.0.bowtie_vs_pave.E7/index \
  -resume
```

### HPV16 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c config/hpv16_tree.config \
  --input_dir analysis-input2/003.0.hpv16_tree/input \
  --outdir analysis-input2/003.0.hpv16_tree/output \
  -resume
```

### HPV18 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c config/hpv18_tree.config \
  --input_dir analysis-input2/004.0.hpv18_tree/input \
  --outdir analysis-input2/004.0.hpv18_tree/output \
  -resume
```

## Reruns and resume

- Nextflow: use `-resume` to reuse successful tasks.
- Scripts: remove a step's `output/` to force a full rerun.

## Troubleshooting

- Check `.nextflow.log` for pipeline errors.
- Inspect process work directories under `work/` and read `.command.sh`, `.command.err`, `.command.out`.
- If tools are missing, confirm the Conda env file in `config/` is referenced by the pipeline.
- Nextflow requires Java 17+; if Conda provides an older Java, use the env in `config/nextflow_java.env.yml`:
- When adding a new Nextflow parameter in a pipeline (e.g. `params.multiqc_config`), also add it to the matching `config/*.config` file to avoid “undefined parameter” warnings.

```
conda env create -f config/nextflow_java.env.yml
conda activate nextflow-java
```

## Reference snapshots

To refresh the reference snapshot used for regression checks:

```
mkdir -p reference-results
for step in analysis-input1/* analysis-input2/*; do
  [ -d "$step" ] || continue
  for sub in output reports index; do
    src="$step/$sub"
    if [ -d "$src" ]; then
      dest="reference-results/$step/$sub"
      mkdir -p "$dest"
      cp -a "$src/." "$dest/"
    fi
  done
done
```

## Updating inputs

- Update sample lists in `metadata/`.
- Ensure reference indices exist in step `index/` or a shared `refdata/` location.

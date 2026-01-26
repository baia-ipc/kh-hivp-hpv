# OPERATIONS

This runbook covers how to run workflows, troubleshoot issues, and rerun safely. For a catalog of what workflows exist, see `SKILLS.md`.

## Conventions

- Configuration is in `config/` and sample lists in `metadata/`.
- Outputs are written to each step's `output/` and `reports/`.
- When changing directory layout, update `CONTENTS.md` and `INVENTORY.md`.

## Running pipelines

### analysis-input1 bucketing (Nextflow)

- Pipeline: `pipelines/centrifuge_bucketing_all.nf`
- Inputs: `metadata/samples-input1.tsv`
- Outputs: `analysis-input1/001.0.centrifuge/{output,reports}`

Example:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/centrifuge_bucketing.config
```

### analysis-input2 bucketing (Nextflow)

- Pipeline: `pipelines/centrifuge_bucketing_all.nf`
- Inputs: `metadata/samples-input2.tsv` (override `--samples_tsv` if needed)
- Outputs: `analysis-input2/001.0.bucketing/{output,reports}`

Example:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/centrifuge_bucketing.config \
  --samples_tsv metadata/samples-input2.tsv \
  --outdir analysis-input2/001.0.bucketing/output \
  --reports_dir analysis-input2/001.0.bucketing/reports
```

### Bowtie vs PAVE mapping (Nextflow)

analysis-input1:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/bowtie_vs_pave.config \
  --reads_dir analysis-input1/001.0.centrifuge/output \
  --outdir analysis-input1/002.0.bowtie_vs_pave/output \
  --reports_dir analysis-input1/002.0.bowtie_vs_pave/reports \
  --index_dir analysis-input1/002.0.bowtie_vs_pave/index
```

analysis-input2:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/bowtie_vs_pave.config \
  --reads_dir analysis-input2/001.0.bucketing/output \
  --outdir analysis-input2/002.0.mapping_vs_pave/output \
  --reports_dir analysis-input2/002.0.mapping_vs_pave/reports \
  --index_dir analysis-input2/002.0.mapping_vs_pave/index
```

## Reruns and resume

- Nextflow: use `-resume` to reuse successful tasks.
- Scripts: remove a step's `output/` to force a full rerun.

## Troubleshooting

- Check `.nextflow.log` for pipeline errors.
- Inspect process work directories under `work/` and read `.command.sh`, `.command.err`, `.command.out`.
- If tools are missing, confirm the Conda env file in `config/` is referenced by the pipeline.
- Nextflow requires Java 17+; if Conda provides an older Java, use the env in `config/nextflow_java.env.yml`:

```
conda env create -f config/nextflow_java.env.yml
conda activate nextflow-java
```

## Updating inputs

- Update sample lists in `metadata/`.
- Ensure reference indices exist in step `index/` or a shared `refdata/` location.

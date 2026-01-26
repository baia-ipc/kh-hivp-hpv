# OPERATIONS

This runbook covers routine operations, troubleshooting, and safe reruns.

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

## Reruns and resume

- Nextflow: use `-resume` to reuse successful tasks.
- Scripts: remove a step's `output/` to force a full rerun.

## Troubleshooting

- Check `.nextflow.log` for pipeline errors.
- Inspect process work directories under `work/` and read `.command.sh`, `.command.err`, `.command.out`.
- If tools are missing, confirm the Conda env file in `config/` is referenced by the pipeline.

## Updating inputs

- Update sample lists in `metadata/`.
- Ensure reference indices exist in step `index/` or a shared `refdata/` location.

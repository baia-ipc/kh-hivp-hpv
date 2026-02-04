# prelim_analysis step 01: Bucketing

## Overview

This step performs taxonomic classification of paired-end reads using Centrifuge
against a prebuilt human + RefSeq archaea/bacteria/viral index, and then assigns each read to a set of
predefined taxonomy "buckets" (e.g. Papillomaviridae, other viruses, host).
The result is a per-sample set of bucketed FASTQ files plus summary tables.

## Implementation

This step is implemented as Nextflow pipelines:

- Per-sample pipeline: `pipelines/centrifuge_bucketing.nf`
- Multi-sample pipeline: `pipelines/centrifuge_bucketing_all.nf`
- User config: `config/user.config`
- Step path config: `config/analyses/prelim_analysis.config` (profile `preliminary_bucketing`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/centrifuge_bucketing.config`

Wrappers under `bin/` call the Nextflow pipelines:

- `bin/prelim_analysis.steps/01.bucketing.run.sh` (all samples)
- `bin/prelim_analysis.steps/single_sample/01.bucketing.run_sample.sh` (one sample / one pair)

## Inputs

- Sample list: `metadata/samples-input1.tsv` (normalized `sample_id` plus `fastq_sample_id` for raw filename prefixes)
- Bucket definitions: `metadata/bucket_taxonomy_ids.tsv`
- Centrifuge index + taxonomy: configured in `config/user.config`
- Optional: build a local index with `scripts/taxonomy_assignment/build_centrifuge_db.sh`

## Outputs

Per run (`outs/prelim_analysis/01.bucketing/<RUN_ID>/`):

- `alignments/`: Centrifuge alignment output (`*.aln.tsv`)
- `reports/`: Centrifuge report files (`*.report.tsv`)
- `kreports/`: Centrifuge kreport summary (`*.kreport.tsv`)
- `krona/` and `krona_wo_human/`: Krona HTML summaries (all reads / excluding human)
- `lca/`: lowest common ancestor tables (`*.lca.tsv`)
- `bucket_assignments/` and `bucket_sizes/`: bucket assignment and size tables
- `buckets/`: bucketed FASTQ outputs (`*.fastq.gz`) and logs

Aggregated, step-level reports (`outs/prelim_analysis/01.bucketing/reports/`):

- bucket count tables (absolute and relative abundances; with and without human)
- MultiQC report: `results/reports/prelim_analysis/01_bucketing.report.html`

## Notes

- The same pipelines are also reused for `outs/targeted_analysis/01.bucketing/` with a
  different sample list (`metadata/samples-input2.tsv`) and different output paths.

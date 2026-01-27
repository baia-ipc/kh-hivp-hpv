# Methods and Results — analysis-input1 step 001 (centrifuge bucketing)

## Methods
Paired-end reads were taxonomically classified against an HPV reference index using Centrifuge, producing per-read assignments and summary reports (Kim et al., 2016). Taxonomic summaries were rendered both as Kraken-style reports and as interactive Krona plots (Ondov et al., 2011). Each read was mapped to a predefined taxonomy bucket to enable downstream grouping, and bucket-wise read sets were generated for subsequent analyses. Aggregate tables of absolute and relative bucket abundance were computed across samples; relative summaries were additionally generated after excluding human assignments. All taxonomic operations used the NCBI taxonomy dump specified for the analysis.

**References**
- Kim et al., 2016. Centrifuge: rapid and sensitive classification of metagenomic sequences. *Genome Research*. DOI: 10.1101/gr.210641.116.
- Ondov et al., 2011. Interactive metagenomic visualization in a Web browser (Krona). *BMC Bioinformatics*. DOI: 10.1186/1471-2105-12-385.

## Results (aggregated from step 001 reports)

**Samples processed**
- Total samples: 72
- Runs: HPV_150123_run01 (22), HPV_160823_run03 (25), HPV_250523_run02 (25)

**Papillomaviridae (absolute counts per sample)**
- Non‑zero Papillomaviridae reads: 56/72 samples
- Median count: 12; max: 8,802
- Binned counts (samples):
  - 0: 16
  - 1–9: 18
  - 10–99: 17
  - 100–999: 14
  - 1,000–9,999: 7
  - ≥10,000: 0

**Papillomaviridae (relative abundance, human excluded)**
- Median: 0.0102; max: 0.9664
- Binned relative abundance (samples):
  - 0: 16
  - >0–0.001: 6
  - 0.001–0.01: 14
  - 0.01–0.1: 13
  - 0.1–0.5: 12
  - >0.5: 11

**Other viruses (relative abundance, human excluded)**
- Binned relative abundance (samples):
  - 0: 1
  - >0–0.001: 5
  - 0.001–0.01: 13
  - 0.01–0.1: 45
  - 0.1–0.5: 7
  - >0.5: 1

**Phi X‑174 spike-in (relative abundance, human excluded)**
- Non‑zero spike-in reads: 40/72 samples (absolute table)
- Binned relative abundance (samples):
  - 0: 32
  - >0–0.001: 10
  - 0.001–0.01: 18
  - 0.01–0.1: 8
  - 0.1–0.5: 0
  - >0.5: 4

**Notes on sources**
- Counts and proportions are from:
  - `analysis-input1/001.0.centrifuge/reports/absolute_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.wo_human.tsv`
- Relative abundance summaries above use the human‑excluded table.

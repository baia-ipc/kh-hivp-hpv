# Methods and Results — analysis-input1 step 001 (centrifuge bucketing)

## Methods
Paired-end reads were taxonomically classified against an HPV reference index
using Centrifuge, producing per-read assignments and summary reports (Kim et
al., 2016). Taxonomic summaries were rendered both as Kraken-style reports and
as interactive Krona plots (Ondov et al., 2011). Each read was mapped to a
predefined taxonomy bucket to enable downstream grouping, and bucket-wise read
sets were generated for subsequent analyses. Aggregate tables of absolute and
relative bucket abundance were computed across samples; relative summaries were
additionally generated after excluding human assignments. All taxonomic
operations used the NCBI taxonomy dump specified for the analysis.

**References**
- Kim et al., 2016. Centrifuge: rapid and sensitive classification of metagenomic sequences. *Genome Research*. DOI: 10.1101/gr.210641.116.
- Ondov et al., 2011. Interactive metagenomic visualization in a Web browser (Krona). *BMC Bioinformatics*. DOI: 10.1186/1471-2105-12-385.

## Results (aggregated from step 001 reports)

Seventy-two samples were processed across three MiSeq runs (HPV_150123_run01, n=22; HPV_160823_run03, n=25; HPV_250523_run02, n=25).

Papillomaviridae reads were detected in most samples (56/72, 78%). In terms of absolute counts, the typical sample had low to moderate Papillomaviridae signal (median 12 reads), but the distribution was broad: 18 samples had only 1–9 reads, 17 had 10–99 reads, 14 had 100–999 reads, and 7 samples showed strong signal with 1,000–9,999 reads; 16 samples had no Papillomaviridae reads. When focusing on the non-human fraction (relative_counts.wo_human.tsv), Papillomaviridae ranged from absent (16/72) to dominant: 11/72 samples had Papillomaviridae accounting for more than half of non-human assignments (>0.5), with a maximum of 0.966. Most samples fell into low-to-intermediate fractions (0.001–0.5), and the median non-human fraction was 0.0102, indicating that in the typical sample Papillomaviridae represented around 1% of non-human assignments.

“Other viruses” assignments were nearly ubiquitous (71/72 samples). In the non-human normalized table, the majority of samples clustered in a narrow band where “Other viruses” represented 1–10% of non-human assignments (45/72 samples in 0.01–0.1). Only one sample had no “Other viruses” signal, and only one sample had “Other viruses” dominating the non-human fraction (>0.5).

Phi X-174 spike-in reads were present in 40/72 samples in absolute counts, but for most samples the relative contribution was small when human reads were excluded. Specifically, 32/72 samples had zero Phi X in the non-human table and a further 28/72 had Phi X at ≤1% of non-human assignments (0–0.01). A small subset (4/72) showed very high Phi X fractions (>0.5), consistent with spike-in dominated libraries.

**Notes on sources**
- Counts and proportions are from:
  - `analysis-input1/001.0.centrifuge/reports/absolute_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.wo_human.tsv`
- Relative abundance summaries above use the human‑excluded table.

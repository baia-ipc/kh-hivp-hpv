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

Seventy-two samples were processed across three MiSeq runs (HPV_150123_run01,
n=22; HPV_160823_run03, n=25; HPV_250523_run02, n=25). Five samples were
controls/technical placeholders (one water control H2O, one HVP control, and
three “Undetermined” FASTQ sets produced by Illumina demultiplexing for reads
that were not assigned to any sample); proportions below are reported for the
remaining 67 non-control samples unless stated otherwise.

Papillomaviridae reads were detected in most non-control samples (51/67, 76%).
In terms of absolute counts, the typical sample had low to moderate
Papillomaviridae signal (median 11 reads), but the distribution was broad: many
samples clustered at very low counts (17 samples with 1–9 reads; 14 with 10–99
reads), while a substantial subset showed higher signal (13 samples with
100–999 reads and 7 samples with 1,000–9,999 reads). Sixteen non-control samples
had no Papillomaviridae reads. When focusing on the non-human fraction
(relative_counts.wo_human.tsv), Papillomaviridae ranged from absent (16/67) to
dominant: 11/67 samples had Papillomaviridae accounting for more than half of
non-human assignments (>0.5), with a maximum of 0.966. Most samples fell into
low-to-intermediate fractions (0.001–0.5), and the median non-human fraction was
0.0143, indicating that in the typical sample Papillomaviridae represented
around 1–2% of non-human assignments.

“Other viruses” assignments were ubiquitous among non-control samples (67/67).
In the non-human normalized table, the majority clustered in a narrow band where
“Other viruses” represented 1–10% of non-human assignments (45/67). Only one
sample showed “Other viruses” dominating the non-human fraction (>0.5),
consistent with a library dominated by non-HPV viral signal.

Phi X-174 spike-in reads were present in 35/67 non-control samples in absolute
counts, but for most samples the relative contribution was small when human
reads were excluded. Specifically, 32/67 samples had zero Phi X in the non-human
table and a further 27/67 had Phi X at ≤1% of non-human assignments (0–0.01).
One non-control sample showed a very high Phi X fraction (>0.5), consistent with
a spike-in dominated library.

As expected, the “Undetermined” FASTQ sets (unassigned reads from the Illumina
pipeline) were strongly dominated by Phi X-174 in the non-human table (Phi X
fractions ~0.72–0.98), and are therefore excluded from the main proportions
above.

**Notes on sources**
- Counts and proportions are from:
  - `analysis-input1/001.0.centrifuge/reports/absolute_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.wo_human.tsv`
- Relative abundance summaries above use the human‑excluded table.

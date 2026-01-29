# Methods and Results — analysis-input1 step 001 (centrifuge bucketing)

## Methods
Paired-end reads were taxonomically classified against a human + RefSeq viral index
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
consistent with a library dominated by non-HPV viral signal
(HPV_250523_run02:KHCA191).

Phi X-174 spike-in reads were present in 35/67 non-control samples in absolute
counts, but for most samples the relative contribution was small when human
reads were excluded. Specifically, 32/67 samples had zero Phi X in the non-human
table and a further 27/67 had Phi X at ≤1% of non-human assignments (0–0.01).
One non-control sample showed a very high Phi X fraction (>0.5), consistent with
a spike-in dominated library (HPV_160823_run03:KHCA-332).

As expected, the “Undetermined” FASTQ sets (unassigned reads from the Illumina
pipeline) were strongly dominated by Phi X-174 in the non-human table (Phi X
fractions ~0.72–0.98), and are therefore excluded from the main proportions
above (HPV_150123_run01:Undetermined, HPV_160823_run03:Undetermined,
HPV_250523_run02:Undetermined).

**Notes on sources**
- Counts and proportions are from:
  - `analysis-input1/001.0.centrifuge/reports/absolute_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.tsv`
  - `analysis-input1/001.0.centrifuge/reports/relative_counts.wo_human.tsv`
- Relative abundance summaries above use the human‑excluded table.

# Methods and Results — analysis-input1 step 002 (bowtie vs PAVE mapping)

## Methods
Bucketed reads assigned to the HPV taxonomy bucket were mapped to the PAVE
reference with Bowtie2 (Langmead & Salzberg, 2012). Alignments were processed
with SAMtools to generate sorted/indexed BAMs and idxstats (Li et al., 2009).
Coverage depth and breadth were computed from per‑base depth files and
summarized with covstats. Variants were called with bcftools mpileup/call and
per‑sample VCF statistics were produced (Li, 2011). Aggregation steps compiled
top‑strain calls, coverage summaries, and E6/E7 variant tables across samples.

**References**
- Langmead & Salzberg, 2012. Fast gapped-read alignment with Bowtie 2. *Nature Methods*. DOI: 10.1038/nmeth.1923.
- Li et al., 2009. The Sequence Alignment/Map format and SAMtools. *Bioinformatics*. DOI: 10.1093/bioinformatics/btp352.
- Li, 2011. A statistical framework for SNP calling, mutation discovery, association mapping and population genetical parameter estimation from sequencing data. *Bioinformatics*. DOI: 10.1093/bioinformatics/btr509.

## Results (aggregated from step 002 reports)

This step operated on the HPV bucket only; 51 non‑control samples had bucketed
reads available. Control/technical samples (H2O, HVP‑*, Undetermined) are
excluded from the summaries below.

Top‑strain calls were present in 34/51 samples, while 17/51 samples had no top
strain call in the aggregated table, consistent with sparse HPV signal for a
subset of samples. The most frequently reported top strains were HPV16, HPV58,
HPV33, HPV18, and HPV66.

Coverage summaries from the filtered table show that 20/51 samples had
substantial coverage breadth (≥0.5) and 13/51 reached near‑complete breadth
(≥0.9) for their best‑covered strain. E6 and E7 breadth signals were observed in
18/51 samples each, indicating detectable coverage across these regions in a
substantial subset of samples.

Variant calls were reported in E6 for 12 samples and in E7 for 8 samples. The
E7‑variant samples were: HPV_150123_run01:KHCA-064,
HPV_160823_run03:KHCA-289, HPV_160823_run03:KHCA-298,
HPV_160823_run03:KHCA-306, HPV_250523_run02:KHCA151,
HPV_250523_run02:KHCA152, HPV_250523_run02:KHCA169,
HPV_250523_run02:KHCA223.

**Notes on sources**
- `analysis-input1/002.0.bowtie_vs_pave/reports/strains.tsv`
- `analysis-input1/002.0.bowtie_vs_pave/reports/cov_stats.tsv`
- `analysis-input1/002.0.bowtie_vs_pave/reports/cov_stats.filtered.tsv`
- `analysis-input1/002.0.bowtie_vs_pave/reports/E6_E7_variants.tsv`

# Methods and Results — analysis-input1 step 003 (VirStrain)

## Methods
Bucketed reads were classified with VirStrain using a reference index built
from the PAVE HPV reference aligned by MAFFT (Li et al., 2022; Katoh et al.,
2002). VirStrain reports per‑sample strain assignments, which were aggregated
across samples into a single table for interpretation.

**References**
- Li et al., 2022. VirStrain: a strain identification tool for RNA viruses. *Genome Biology*. DOI: 10.1186/s13059-022-02609-x.
- Katoh et al., 2002. MAFFT: a novel method for rapid multiple sequence alignment. *Nucleic Acids Research*. DOI: 10.1093/nar/gkf436.

## Results (aggregated from step 003 reports)

Fifty‑one non‑control samples were processed in this step (HPV bucket only).
VirStrain reported “No reads or too few reads” for 16/51 samples and “Too many
possible strains” for 11/51 samples. The remaining 24/51 samples received a
strain assignment.

Among the assigned samples, 21 had a single strain call and three had multiple
strain calls. The multi‑strain samples were: HPV_150123_run01:KHCA-037,
HPV_160823_run03:KHCA-256, HPV_250523_run02:KHCA223. The most frequently
assigned strains included HPV16, HPV58, HPV18, HPV71, and HPV52.

**Notes on sources**
- `analysis-input1/003.0.virstrain/reports/strains.tsv`

# Methods and Results — analysis-input1 step 004 (bowtie vs PAVE E6)

## Methods
HPV‑bucket reads were mapped against the E6 gene reference from PAVE using
Bowtie2 (Langmead & Salzberg, 2012). Alignments were processed with SAMtools,
and per‑base depth was summarized into depth statistics and per‑feature coverage
metrics (Li et al., 2009). Aggregation steps compiled top‑strain calls and depth
tables across samples.

**References**
- Langmead & Salzberg, 2012. Fast gapped-read alignment with Bowtie 2. *Nature Methods*. DOI: 10.1038/nmeth.1923.
- Li et al., 2009. The Sequence Alignment/Map format and SAMtools. *Bioinformatics*. DOI: 10.1093/bioinformatics/btp352.

## Results (aggregated from step 004 reports)

Fifty‑one non‑control samples were processed for the E6‑specific mapping. Top‑strain
calls were present in 13/51 samples, while 38/51 samples had no top‑strain call in
the aggregated table, indicating sparse or low‑coverage E6 signal in most samples.
The most frequent E6 top‑strain calls were HPV16_E6, HPV56_E6, HPV18_E6, HPV71_E6,
and HPV90_E6.

Depth statistics showed no samples with high breadth in the filtered table
(0/51 with avg breadth ≥0.5), consistent with limited E6 coverage for most samples.

**Notes on sources**
- `analysis-input1/004.0.bowtie_vs_pave.E6/reports/strains.tsv`
- `analysis-input1/004.0.bowtie_vs_pave.E6/reports/depth_stats.unfiltered.tsv`
- `analysis-input1/004.0.bowtie_vs_pave.E6/reports/depth_stats.filtered.tsv`

# Methods and Results — analysis-input1 step 005 (bowtie vs PAVE E7)

## Methods
HPV‑bucket reads were mapped against the E7 gene reference from PAVE using
Bowtie2, with SAMtools‑processed alignments and depth‑based coverage summaries
analogous to the E6 step (Langmead & Salzberg, 2012; Li et al., 2009). Top‑strain
and depth summaries were aggregated across samples.

**References**
- Langmead & Salzberg, 2012. Fast gapped-read alignment with Bowtie 2. *Nature Methods*. DOI: 10.1038/nmeth.1923.
- Li et al., 2009. The Sequence Alignment/Map format and SAMtools. *Bioinformatics*. DOI: 10.1093/bioinformatics/btp352.

## Results (aggregated from step 005 reports)

Fifty‑one non‑control samples were processed for the E7‑specific mapping. Top‑strain
calls were present in 13/51 samples, while 38/51 samples had no top‑strain call in
the aggregated table. The most frequent E7 top‑strain calls were HPV16_E7,
HPV56_E7, HPV66_E7, HPV18_E7, and HPV71_E7.

As with E6, no samples reached high breadth in the filtered table (0/51 with
avg breadth ≥0.5), indicating low E7 coverage in most samples.

**Notes on sources**
- `analysis-input1/005.0.bowtie_vs_pave.E7/reports/strains.tsv`
- `analysis-input1/005.0.bowtie_vs_pave.E7/reports/depth_stats.unfiltered.tsv`
- `analysis-input1/005.0.bowtie_vs_pave.E7/reports/depth_stats.filtered.tsv`

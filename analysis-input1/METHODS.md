# Methods — analysis-input1

Paired-end Illumina MiSeq reads were first screened for taxonomic composition
using Centrifuge, with classification performed against an HPV-focused index
and interpreted using the corresponding NCBI taxonomy dump (Kim et al., 2016).
Per-sample summaries were produced as Kraken-style reports and interactive Krona
visualizations to support inspection of broad taxonomic composition (Ondov et
al., 2011). To enable downstream analyses targeting HPV reads, individual read
assignments were mapped to a predefined set of taxonomy “buckets” and the reads
assigned to the HPV bucket were extracted into per-sample FASTQ files for
subsequent mapping-based analyses.

HPV-bucket reads were aligned to the PAVE human HPV reference using Bowtie2
(Langmead & Salzberg, 2012). Alignments were converted, sorted, and indexed
using SAMtools (Li et al., 2009). For each sample, per-base depth profiles were
computed and summarized into coverage depth and breadth statistics across the
full reference and, where applicable, for specific genomic regions. Variant
calling was performed using bcftools mpileup and call, followed by per-sample
variant statistics reporting (Li, 2011). Aggregate summaries were compiled
across samples to report dominant (“top”) strain signals, coverage metrics, and
variant calls.

In parallel, strain inference from the same HPV-bucket reads was performed using
VirStrain with an index built from a multiple sequence alignment of the PAVE HPV
reference, generated with MAFFT (Katoh et al., 2002; Li et al., 2022). VirStrain
strain assignments were aggregated across samples to provide an independent
strain-level summary.

To focus on clinically relevant oncogene regions, HPV-bucket reads were also
mapped to gene-specific PAVE reference subsets for E6 and E7, again using
Bowtie2 with SAMtools-based processing. Per-base depth was summarized into
gene-level depth and breadth metrics, and aggregated across samples to compare
coverage of these loci.

**References**
- Kim et al., 2016. Centrifuge: rapid and sensitive classification of metagenomic sequences. *Genome Research*. DOI: 10.1101/gr.210641.116.
- Ondov et al., 2011. Interactive metagenomic visualization in a Web browser (Krona). *BMC Bioinformatics*. DOI: 10.1186/1471-2105-12-385.
- Langmead & Salzberg, 2012. Fast gapped-read alignment with Bowtie 2. *Nature Methods*. DOI: 10.1038/nmeth.1923.
- Li et al., 2009. The Sequence Alignment/Map format and SAMtools. *Bioinformatics*. DOI: 10.1093/bioinformatics/btp352.
- Li, 2011. A statistical framework for SNP calling, mutation discovery, association mapping and population genetical parameter estimation from sequencing data. *Bioinformatics*. DOI: 10.1093/bioinformatics/btr509.
- Katoh et al., 2002. MAFFT: a novel method for rapid multiple sequence alignment. *Nucleic Acids Research*. DOI: 10.1093/nar/gkf436.
- Li et al., 2022. VirStrain: a strain identification tool for RNA viruses. *Genome Biology*. DOI: 10.1186/s13059-022-02609-x.

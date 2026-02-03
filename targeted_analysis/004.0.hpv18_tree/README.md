(files are organized as: input/ and output/; commands assume this directory as cwd)

(1) HPV18 lineages table HPV18_lineages.tsv downloaded from PAVE
website link: https://pave.niaid.nih.gov/explore/variants/variant_genomes
Search: HPV18
Copy-paste table into a file under input/

(2) HPV18 NCBI Virus sequences download
open NCBI virus
search "Human papillomavirus 18"
use "Sequence Quality: Nucleotide Completeness: complete" filter
Download all sequences in FASTA format, use custom definition line
  Download all results -> Sequence Data (FASTA format) -> Nucleotide
  Build custom : Accession Country Length Species GenBank/RefSeq GenBank Title Collection Date
  save as input/HPV18-NCBIVirus.fasta
Download sequence metadata in TSV format, use custom fields definition
  Download all results -> Results Table -> TSV format
  Columns: Accession       GenBank_RefSeq  Organism_Name   Species Genotype
           Isolate GenBank_Title   Length  Nuc_Completeness        Geo_Location
           Country Host    Tissue_Specimen_Source  Submitters Publications
           Collection_Date Release_Date    Molecule_type
  save as input/HPV18-NCBIVirus.tsv

(3) prepare lineages reference fasta
  This is now shared with the SNP‑to‑lineage comparison in step 002.
  Follow the repository root README instructions and place
  intermediate_files/refdata/hpv18_tree/lineages_ref_renamed.fasta before running this step.

(4) select and prepare NCBI Virus genomes
  # one per country, except SEA and EA where all are included
  run ../../scripts/phylo_tree/hpv18_select_ncbi_genomes.sh --init-selection \
    input/HPV18-NCBIVirus.tsv input/HPV18-NCBIVirus.fasta \
    input/HPV18-NCBIVirus.acc_country.tsv \
    input/HPV18-NCBIVirus.acc_country.selected.tsv \
    input/selected.fasta input/selected_renamed.fasta
  manually edit input/HPV18-NCBIVirus.acc_country.selected.tsv to select genomes to include
  re-run ../../scripts/phylo_tree/hpv18_select_ncbi_genomes.sh with the same arguments
  # this writes input/selected.fasta and input/selected_renamed.fasta
  # it also removes spaces in FASTA IDs and skips THAILAND/GQ180787.1 by default

(5) prepare outgroups.fasta
  HPV39, 45 and 59 were selected as outgroups
  they were searched on Pave "Reference Genomes" page
  followed the link to Genbank
  downloaded as Fasta
  Renamed to HPVxx/Accession and saved under input/ (HPV39.fasta, HPV45.fasta, HPV59.fasta)
  concatenated into input/outgroups.fasta

(6) prepare samples.fasta
  extracted the reference sequence from the downloaded PAVE:
  ../../scripts/phylo_tree/hpv18_prepare_samples.sh
  # this writes input/HPV18REF.fas, the consensus FASTAs (with KHCA-<sample>-HPV18 IDs), and input/samples.fasta
  # defaults: run ID inferred from metadata/samples-input2.tsv (fastq_dir) and samples from reports/strains.tsv

(7) build the tree
  run ../../bin/targeted_analysis.steps/004.0.hpv18_tree.run.sh (Nextflow pipeline)
  outputs go to output/

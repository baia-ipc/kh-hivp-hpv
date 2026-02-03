(files are organized as: input/ and output/; commands assume this directory as cwd)

(1) HPV16 lineages table HPV16_lineages.tsv downloaded from PAVE
website link: https://pave.niaid.nih.gov/explore/variants/variant_genomes
Search: HPV16
Copy-paste table into a file under input/

(2) HPV16 NCBI Virus sequences download
open NCBI virus
search "Human papillomavirus 16"
use "Sequence Quality: Nucleotide Completeness: complete" filter
Download all sequences in FASTA format, use custom definition line
  Download all results -> Sequence Data (FASTA format) -> Nucleotide
  Build custom : Accession Country Length Species GenBank/RefSeq GenBank Title Collection Date
  save as input/HPV16-NCBIVirus.fasta
Download sequence metadata in TSV format, use custom fields definition
  Download all results -> Results Table -> TSV format
  Columns: Accession       GenBank_RefSeq  Organism_Name   Species Genotype
           Isolate GenBank_Title   Length  Nuc_Completeness        Geo_Location
           Country Host    Tissue_Specimen_Source  Submitters Publications
           Collection_Date Release_Date    Molecule_type
  save as input/HPV16-NCBIVirus.tsv

(3) prepare lineages reference FASTA
  This is now shared with the SNP‑to‑lineage comparison in step 02.
  Follow the repository root README instructions and place
  intermediate_files/refdata/hpv16_tree/lineages_ref_renamed.fasta before running this step.

(4) select and prepare NCBI Virus genomes
  create a selection table with Accession and Country (two columns)
    ../../scripts/phylo_tree/hpv16_select_ncbi_genomes.sh --init-selection \
      input/HPV16-NCBIVirus.tsv input/HPV16-NCBIVirus.fasta \
      input/selected input/selected.fasta input/selected_renamed.fasta
  manually edit input/selected to keep the genomes to include
  re-run ../../scripts/phylo_tree/hpv16_select_ncbi_genomes.sh with the same arguments
  # this writes input/selected.fasta and input/selected_renamed.fasta

(5) prepare outgroups.fasta (and distant_outgroups.fasta)
  select outgroup HPV reference genomes from PAVE or GenBank
  download as FASTA, rename to HPVxx/Accession, and save under input/

(6) prepare samples.fasta
  run ../../scripts/phylo_tree/hpv16_prepare_samples.sh
  # this writes input/HPV16REF.fas, the consensus FASTAs (with KHCA-<sample>-HPV16 IDs), and input/samples.fasta
  # defaults: run ID inferred from metadata/samples-input2.tsv (fastq_dir); override with BCF_RUN_ID/BCF_DIR

(7) build the tree
  run ../../bin/targeted_analysis.steps/03.hpv16_tree.run.sh (Nextflow pipeline)
  outputs go to output/

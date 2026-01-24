
(files are organized as: input/, scripts/, output/; commands assume this directory as cwd)

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

(3) prepare lineages reference fasta
  run scripts/extract_lineages_fasta.sh
  this will create input/lineages_ref.fasta
  run scripts/rename_lineages.py to add lineage prefix from HPV16_lineages.tsv
    python3 scripts/rename_lineages.py input/HPV16_lineages.tsv 6 4 input/lineages_ref.fasta input/lineages_ref_renamed.fasta

(4) select and prepare NCBI Virus genomes
  create a selection table with Accession and Country (two columns)
    cut -f 1,10 input/HPV16-NCBIVirus.tsv > input/selected
  manually edit input/selected to keep the genomes to include
  seqkit grep -f <(cut -f 1 input/selected) -r input/HPV16-NCBIVirus.fasta > input/selected.fasta
  python3 scripts/rename_lineages.py input/selected 1 2 input/selected.fasta input/selected_renamed.fasta
  # if needed, remove spaces in FASTA IDs and drop duplicate genomes manually

(5) prepare outgroups.fasta (and distant_outgroups.fasta)
  select outgroup HPV reference genomes from PAVE or GenBank
  download as FASTA, rename to HPVxx/Accession, and save under input/

(6) prepare samples.fasta
  extract the reference sequence from the downloaded PAVE:
  seqkit grep -r -p "HPV16REF.*" analysis-3/steps/002.0.mapping_vs_pave/index/pave_hsa.fas > input/HPV16REF.fas
  in the directory containing the BCF files (example):
    analysis-3/steps/002.0.mapping_vs_pave/output/<RUNID>
    for sample in <SAMPLES>; do
      bcftools consensus -f /path/to/analysis-3/steps/003.0.hpv16_tree/input/HPV16REF.fas \
        KHCA-$sample.bcf.gz > /path/to/analysis-3/steps/003.0.hpv16_tree/input/KHCA-$sample.HPV16REF.consensus.fa
    done
  manually change the Fasta IDs to KHCA-$sample-HPV16
  concatenate them into input/samples.fasta
    cat input/KHCA-*.HPV16REF.consensus.fa > input/samples.fasta

(7) build the tree
  run scripts/1_cat_all.sh, scripts/2_run_mafft.sh, scripts/3_run_trimal.sh, scripts/4_run_iqtree.sh
  outputs go to output/

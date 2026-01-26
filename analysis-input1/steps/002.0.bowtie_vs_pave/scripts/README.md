# Method

1) create bowtie2 index
2) alignment using `bowtie --all`, i.e. allowing multiple matches
   and default alignment parameters;
   reason: without `-all`, reads are aligned randomly if they match multiple
           strains, which would be OK if we had many more reads
3) count alignments with `samtools idxstats`
4) own python script for _rough_ strain assignment;
   method: select strains with at least N reads (parameter value used: 10),
           and which have not less than `T*C` reads where:
           - T is a parameter (parameter value used: 0.2)
           - C is the count for the strain with the highest number of alignments
   note: for more advanced strain assignments see virstrain step

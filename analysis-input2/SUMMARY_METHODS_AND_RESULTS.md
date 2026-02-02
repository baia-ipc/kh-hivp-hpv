
# Bucketing

 

In the first step the reads are first classified into buckets by centrifuge.
The results of this step are in tables (TSV) under /srv/giorgio/virology/HPV/analysis-input2/001.0.bucketing/reports
and I summarize them here:
- Indeed, while in the first sequencing, without enrichment, all readsets had over 99% of human sequences, here the numbers are lower BUT not to a point that such filtering is not necessary.

- 7 samples have still over 99% human sequences (056, 078, 082, 092, 152, 204, 328), so that the enrichment didn’t work as expected; of these 7 in 5 cases (056, 078, 082, 092, 328) there is almost no viral DNA (number of Papillomaviridae read pairs: 6, 135, 29, 40, 33), while for the other 2 there are fewer Papillomaviridae read pairs than for other samples (152: 12531; 204: 1061)
- for the remaining 9 samples there are less human reads, with a variable relative proportion between 53% and 89%. For these samples there are then plently of Papillomaviridae reads to proceed with the next step, ranging from about 128k read pairs of sample 229 to 1,4M read pairs of sample 064.
- this time some HIV reads were present, but a negligible amount (1 read pair, 6 read pairs), in two of the samples with almost no Papillomaviridae (082, 092)
- in one case (229) there is a significant amount (2.5% of reads) classified as other viruses. For comparison, in this sample Papillomaviridae is 11.9%. Having a closer look to the assignments, these reads are mostly “Human betaherpesvirus 5”
(see e.g. /srv/giorgio/virology/HPV/analysis-input2/001.0.bucketing/output/HPV_11092024/krona/KHCA-229.krona.html)

# Strain assignment

The results are reported in /srv/giorgio/virology/HPV/analysis-input2/002.0.mapping_vs_pave/reports/strains.tsv
and summarized here:
- of the patients mentioned above, with unefficient enrichment, I skip commenting on samples 056, 078, 082, 092, 328, 204 given the negligible counts; I keep considering 152, which has 12.5k read pairs
- for all these lost samples we didn’t have any usable result also in the first analysis

## HPV16

- HPV16 was the main strain for samples 064, 149, 152, 186, 298, 306; these are all consistent with the previous analysis
- sample 186 has a clear co-infection with HPV70 (already noticed in the previous analysis, in which we had more HPV70 reads than HPV16); other samples have second highest counts for different strains (e.g. HPV33, HPV30, HPV91)

- sample 056 sequencing did not work (low counts, see above)
- four of the HPV16 samples are from patients with CIN2+ lesions (064, 149, 298, 306), two without lesions (152, 186)

## HPV18
- almost except one of the unusable samples with low counts are for HPV18 (078, 082, 092, 328, 204) – only sample 056 was for HPV16
- HPV18 was the main strain for samples 075, 213, 229, 237; these are all consistent with the previous analysis; for all of these, samples the second highest counts are in strain HPV97
- two of the HPV18 samples are from patients with CIN2+ lesions (213, 229), two not (075, 237)

# Coverage analysis

## HPV16

- the new sequencing greatly improved results for all these strains in terms of coverage.

- previous results (coverage depth/breadth)
- CIN2+:
KHCA-064      HPV16   104.46610169491525    1.0
KHCA-149       HPV16   5.186061219327093     0.9504174045029092
KHCA-298      HPV16   21.92006071338224     1.0
KHCA-306      HPV16   31.163420187199595    0.9996205413609917
- CIN2-:
KHCA-152       HPV16   1.4228434100683025    0.61409056412851
KHCA-186       HPV16   0.06830255502150266   0.05325069567417152

- current results (coverage depth/breadth)
- CIN2+:
KHCA-064      HPV16   27417.72413356944     1.0
KHCA-149      HPV16   9084.630280799392     1.0
KHCA-298      HPV16   24482.69251201619     1.0
KHCA-306      HPV16   24278.075259296736    1.0
- CIN2-:
KHCA-152      HPV16   237.73577030103718    0.9998735137869972
KHCA-186      HPV16   3397.057930685555     1.0

- The coverage of KHCA-152 is not perfect, given the lower counts compare to all other;
but both genes of interested are completely covered, with relatively good depth (E6:57; E7:20)

## HPV18

- for three of the four samples, we did not have good results in the previous analysis
- here are the coverage depth and breadth in the previous and current sequencing:
  - CIN2+:
    - KHCA-213       previous:   5.364006618302151     0.9618174875906834      current:   3272.0089092528956    0.9803996436298842
    - KHCA-229      previous:   0.34631538755250096   0.22069492172584956      current:   2416.1597301769125    0.9742904416443935
  - CIN2-:
    - KHCA-075      previous:   425.25544100801835    1.0      current:   13540.981163293878    1.0

    - KHCA-237      previous:   1.8359424716813033    0.7146493572610411      current:   4755.803741886216     0.9996181748759069
- for KHCA-229 the E6 gene is not covered completely (breadth: 85.7%), while E7 is completely covered
- the same is true for KHCA-213, E6 gene coverage of 93.9%, while E7 is completely covered
- for the other two the coverage of E6 and E7 is complete
- the result is intriguing, since the coverage depth for E6 is high in both KHCA-229 (309) and KHCA-213 (497) - might these samples have a rearrangement in the gene which prevents successful alignment?


# Variants

The results are found in /srv/giorgio/virology/HPV/analysis-input2/002.0.mapping_vs_pave/reports/E6_E7_variants.tsv and summarized here.
In total only 1 new variant has been found through the new analysis (in KHCA-152, see below)

## HPV16
- CIN2+:
  - KHCA-064: we find again the same variants as in the previous analysis (position E6:178, E7:666)
  - KHCA-149: we do not find any variant, as in the previous analysis
  - KHCA-298: we find again the same variant as in the previous analysis (position E6:178); variant already observed in patient 064
-   KHCA-306:
    - in the previous analysis we had observed variants in both E6 (8 variants, positions: 109, 132, 143, 145, 286, 289, 335, 403) and E7 (3 variants, positions: 647, 789, 795)
    - all variants have been confirmed, no new variants have been found
- CIN2-:
  - KHCA-152:

the new results confirm the two variants found in the previous analysis (E6: 178, E7:647)
BUT an additional variant was also found at position 800 (E7 gene)!
  - KHCA-186: no variants found, as in the previous analysis

## HPV18

- no variants were found in the HPV18 genes!
- this reflects the results of the previous analysis

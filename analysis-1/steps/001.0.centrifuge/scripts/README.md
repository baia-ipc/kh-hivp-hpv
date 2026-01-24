# Running the analysis

## One sample

"run.sh" runs the analysis for one sample of one run.

It runs:

(1) centrifuge
    (==> output/<runID>/alignments)

(2) a script of centrifuge to create a krona-style report
    (==> output/<runID>/kreports)

(3a) Krona with all data
    (==> output/<runID>/krona)

(3b) Krona ignoring assignments to the human genome
    (==> `output/<runID>/krona_wo_human`)

(4) run own script `compute_lca.py`
    goal: compute the lowest common ancestor using the output of centrifuge;
    note: normally this would not be necessary if one uses centrifuge -k 1,
          but this option is broken
    (==> output/<runID>/lca)

(5) run own script `assign_to_bucket.py`
    function: accepts a list of subtrees of the taxonomic tree and assigns each
              read (through their LCA assignment) to the lowest bucket and
              supports nested buckets (e.g. if we a bucket Viruses and a bucket
              Papillomaviridae, it puts it in the specific one, if it belongs
              to it, in the less specific otherwise
    (==> `output/<runID>/bucket_assignments`;
     ==> `output/<runID>/bucket_sizes`)

(6) run own script `bucketize_fastq.py`
    function: uses the bucket assignments of `assign_to_bucket.py`
              to separate the reads in fastq into the buckets
    (==> `output/<runID>/buckets`)


## All samples

`run_all.sh` is a wrapper script running run.sh for all samples.
It reads the sample list from `metadata/centrifuge_samples.tsv`.

It runs:

(1) run own script `run.sh` for each sample
    function: see previous section

(2) the own script `aggregate_bucket_counts.py`
    function: collect the counts for all samples and creates tables from it

# Metadata

The `metadata` directory of this step contains bucket definitions
used by the scripts.

#!/usr/bin/env nextflow
nextflow.enable.dsl=2

def normalizeSampleId(String filename) {
    def base = filename
    base = base.replaceFirst(/\.fastq(\.gz)?$/, '')
    base = base.replaceFirst(/_R[12].*/, '')
    base = base.replaceFirst(/_S\d+_.*/, '')
    return base
}

workflow {
    if (!params.reads) {
        error "params.reads is required. Set it in the config file."
    }

    reads_ch = Channel
        .fromFilePairs(params.reads, size: 2)
        .map { sample_key, reads ->
            def r1 = reads.find { it.name.contains('_R1') }
            def r2 = reads.find { it.name.contains('_R2') }
            if (!r1 || !r2) {
                error "Could not find R1/R2 pair for ${reads*.name}"
            }
            def sample_id = normalizeSampleId(r1.name)
            def run_id = r1.parent.parent.name
            tuple(run_id, sample_id, r1, r2)
        }

    align_out = CENTRIFUGE_ALIGN(reads_ch)
    CENTRIFUGE_KREPORT(align_out)
    KRONA_PLOTS(align_out)

    lca_out = COMPUTE_LCA(align_out)
    buckets_out = ASSIGN_BUCKETS(lca_out)

    bucketize_in = buckets_out
        .join(reads_ch, by: [0, 1])
        .map { run_id, sample_id, bkt, bsz, run_id2, sample_id2, r1, r2 ->
            tuple(run_id, sample_id, bkt, r1, r2)
        }

    BUCKETIZE_READS(bucketize_in)
}

process CENTRIFUGE_ALIGN {
    tag "${run_id}:${sample_id}"
    publishDir "${params.outdir}/${run_id}/alignments", mode: 'copy', pattern: "*.aln.tsv"
    publishDir "${params.outdir}/${run_id}/reports", mode: 'copy', pattern: "*.report.tsv"

    input:
    tuple val(run_id), val(sample_id), path(r1), path(r2)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.aln.tsv"), path("${sample_id}.report.tsv")

    script:
    """
    centrifuge -x "${params.index}" -1 "$r1" -2 "$r2" \\
      -S "${sample_id}.aln.tsv" \\
      --report-file "${sample_id}.report.tsv" \\
      -p ${params.threads}
    """
}

process CENTRIFUGE_KREPORT {
    tag "${run_id}:${sample_id}"
    publishDir "${params.outdir}/${run_id}/kreports", mode: 'copy', pattern: "*.kreport.tsv"

    input:
    tuple val(run_id), val(sample_id), path(aln), path(report)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.kreport.tsv")

    script:
    """
    centrifuge-kreport -x "${params.index}" "$aln" > "${sample_id}.kreport.tsv"
    """
}

process KRONA_PLOTS {
    tag "${run_id}:${sample_id}"
    publishDir "${params.outdir}/${run_id}/krona", mode: 'copy', pattern: "*.krona.html"
    publishDir "${params.outdir}/${run_id}/krona_wo_human", mode: 'copy', pattern: "*.krona_wo_human.html"

    input:
    tuple val(run_id), val(sample_id), path(aln), path(report)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.krona.html"), path("${sample_id}.krona_wo_human.html")

    script:
    """
    ktImportTaxonomy -m 6 -t 2 \\
      -o "${sample_id}.krona.html" \\
      "$report"

    awk -F'\\t' -v tid="${params.homo_sapiens_tid}" '\$2 != tid {print}' "$report" | \\
      ktImportTaxonomy -m 6 -t 2 \\
      -o "${sample_id}.krona_wo_human.html" -
    """
}

process COMPUTE_LCA {
    tag "${run_id}:${sample_id}"
    publishDir "${params.outdir}/${run_id}/lca", mode: 'copy', pattern: "*.lca.tsv"

    input:
    tuple val(run_id), val(sample_id), path(aln), path(report)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.lca.tsv")

    script:
    """
    "${params.scripts_dir}/compute_lca.py" "${params.taxdump}/nodes.dmp" \\
      "$aln" "${sample_id}.lca.tsv"
    """
}

process ASSIGN_BUCKETS {
    tag "${run_id}:${sample_id}"
    publishDir "${params.outdir}/${run_id}/bucket_assignments", mode: 'copy', pattern: "*.bkt.tsv"
    publishDir "${params.outdir}/${run_id}/bucket_sizes", mode: 'copy', pattern: "*.bsz.tsv"

    input:
    tuple val(run_id), val(sample_id), path(lca)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.bkt.tsv"), path("${sample_id}.bsz.tsv")

    script:
    """
    "${params.scripts_dir}/assign_to_buckets.py" "${params.taxdump}/nodes.dmp" \\
      "$lca" 2 "${sample_id}.bkt.tsv" \\
      \$(tail -n+1 "${params.buckets}" | cut -f 1) > "${sample_id}.bsz.tsv"
    """
}

process BUCKETIZE_READS {
    tag "${run_id}:${sample_id}"
    publishDir "${params.outdir}/${run_id}/buckets", mode: 'copy', pattern: "*.fastq.gz"

    input:
    tuple val(run_id), val(sample_id), path(bkt), path(r1), path(r2)

    output:
    tuple val(run_id), val(sample_id), path("buckets/*")

    script:
    """
    mkdir -p buckets

    "${params.scripts_dir}/bucketize_fastq.py" \\
      "$bkt" 1 3 "$r1" "buckets/${sample_id}.R1" \\
      --skip "${params.homo_sapiens_tid}" > "buckets/${sample_id}.R1.log"

    "${params.scripts_dir}/bucketize_fastq.py" \\
      "$bkt" 1 3 "$r2" "buckets/${sample_id}.R2" \\
      --skip "${params.homo_sapiens_tid}" > "buckets/${sample_id}.R2.log"
    """
}

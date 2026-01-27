#!/usr/bin/env nextflow
nextflow.enable.dsl=2

def normalizeSampleId(String filename) {
    def base = filename
    base = base.replaceFirst(/\.fastq(\.gz)?$/, '')
    base = base.replaceFirst(/_R[12].*/, '')
    base = base.replaceFirst(/_S\d+_.*/, '')
    return base
}

workflow CENTRIFUGE_BUCKETING {
    take:
    reads_ch

    main:
    krona_ready = KRONA_UPDATE()
    /*
     * Optional: skip the expensive Centrifuge alignment step if the alignment/report files
     * already exist on disk (e.g. copied into params.outdir).
     *
     * Expected layout (default root is params.outdir):
     *   <root>/<run_id>/alignments/<sample_id>.aln.tsv
     *   <root>/<run_id>/reports/<sample_id>.report.tsv
     */
    def align_out
    if (params.skip_align) {
        def precomputed_root = params.precomputed_root ?: params.outdir
        if (!precomputed_root) {
            error "params.precomputed_root is required when params.skip_align is set (or set params.outdir)"
        }

        align_out = reads_ch.map { run_id, sample_id, r1, r2 ->
            def aln_path = "${precomputed_root}/${run_id}/alignments/${sample_id}.aln.tsv"
            def report_path = "${precomputed_root}/${run_id}/reports/${sample_id}.report.tsv"
            def aln_file = file(aln_path)
            def report_file = file(report_path)
            if (!aln_file.exists()) {
                error "Missing precomputed alignment file: ${aln_path} (run_id=${run_id} sample_id=${sample_id})"
            }
            if (!report_file.exists()) {
                error "Missing precomputed report file: ${report_path} (run_id=${run_id} sample_id=${sample_id})"
            }
            tuple(run_id, sample_id, aln_file, report_file)
        }
    } else {
        align_out = CENTRIFUGE_ALIGN(reads_ch)
    }
    CENTRIFUGE_KREPORT(align_out)
    krona_in = align_out.combine(krona_ready)
    KRONA_PLOTS(krona_in)

    lca_out = COMPUTE_LCA(align_out)
    buckets_out = ASSIGN_BUCKETS(lca_out)

    bucketize_in = buckets_out
        .join(reads_ch, by: [0, 1])
        .map { run_id, sample_id, bkt, bsz, r1, r2 ->
            tuple(run_id, sample_id, bkt, r1, r2)
        }

    bucketized = BUCKETIZE_READS(bucketize_in)

    emit:
    bucketized
}

workflow {
    if (!params.reads) {
        error "params.reads is required. Set it in the config file."
    }
    if (!params.outdir) {
        error "params.outdir is required. Set it in the config file or on the command line."
    }
    if (!params.buckets) {
        error "params.buckets is required. Set it in the config file or on the command line."
    }
    if (!params.conda_env) {
        params.conda_env = "${workflow.projectDir}/../config/centrifuge_bucketing.env.yml"
    }
    def index_file = new File("${params.index}.1.cf")
    if (!index_file.exists()) {
        error "Centrifuge index not found: ${index_file} (check params.index)"
    }
    def nodes_file = new File("${params.taxdump}/nodes.dmp")
    if (!nodes_file.exists()) {
        error "Taxdump nodes.dmp not found: ${nodes_file} (check params.taxdump)"
    }
    def buckets_file = new File("${params.buckets}")
    if (!buckets_file.exists()) {
        error "Bucket metadata not found: ${buckets_file} (check params.buckets)"
    }
    def conda_env_file = new File("${params.conda_env}")
    if (!conda_env_file.exists()) {
        error "Conda env definition not found: ${conda_env_file} (check params.conda_env)"
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

    CENTRIFUGE_BUCKETING(reads_ch)
}

process CENTRIFUGE_ALIGN {
    tag "${run_id}:${sample_id}"
    conda params.conda_env
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

process KRONA_UPDATE {
    tag "krona_db"
    conda params.conda_env

    output:
    path("krona_db.ready")

    script:
    """
    if [ ! -e "\$CONDA_PREFIX/opt/krona/taxonomy/taxonomy.tab" ]; then
      ktUpdateTaxonomy.sh
    fi

    touch krona_db.ready
    """
}

process CENTRIFUGE_KREPORT {
    tag "${run_id}:${sample_id}"
    conda params.conda_env
    publishDir "${params.outdir}/${run_id}/kreports", mode: 'copy', pattern: "*.kreport.tsv"

    input:
    tuple val(run_id), val(sample_id), path(aln), path(report)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.kreport.tsv")

    script:
    """
    set +e
    centrifuge-kreport -x "${params.index}" "$aln" > "${sample_id}.kreport.tsv" 2> kreport.err
    status=\$?
    set -e
    if [ "\$status" -ne 0 ]; then
      if [ "\$status" -eq 255 ] && grep -q "No sequence matches" kreport.err; then
        echo "No sequence matches for ${sample_id}; writing empty kreport." >&2
        : > "${sample_id}.kreport.tsv"
      else
        cat kreport.err >&2
        exit "\$status"
      fi
    fi
    """
}

process KRONA_PLOTS {
    tag "${run_id}:${sample_id}"
    conda params.conda_env
    publishDir "${params.outdir}/${run_id}/krona", mode: 'copy', pattern: "*.krona.html"
    publishDir "${params.outdir}/${run_id}/krona_wo_human", mode: 'copy', pattern: "*.krona_wo_human.html"

    input:
    tuple val(run_id), val(sample_id), path(aln), path(report), path(krona_ready)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.krona.html"), path("${sample_id}.krona_wo_human.html")

    script:
    """
    if ! awk -F'\\t' '\$2 ~ /^[0-9]+\$/ {found=1; exit} END {exit !found}' "$report"; then
      cat > "${sample_id}.krona.html" <<'EOF'
    <html><body><p>No taxonomic assignments found.</p></body></html>
EOF
      cp "${sample_id}.krona.html" "${sample_id}.krona_wo_human.html"
      exit 0
    fi

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
    conda params.conda_env
    publishDir "${params.outdir}/${run_id}/lca", mode: 'copy', pattern: "*.lca.tsv"

    input:
    tuple val(run_id), val(sample_id), path(aln), path(report)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.lca.tsv")

    script:
    """
    if awk -F'\\t' '\$3 ~ /^[0-9]+\$/ {found=1; exit} END {exit !found}' "$aln"; then
      "${params.scripts_dir}/compute_lca.py" "${params.taxdump}/nodes.dmp" \\
        "$aln" "${sample_id}.lca.tsv"
    else
      echo "No taxonomy assignments for ${sample_id}; writing empty LCA." >&2
      : > "${sample_id}.lca.tsv"
    fi
    """
}

process ASSIGN_BUCKETS {
    tag "${run_id}:${sample_id}"
    conda params.conda_env
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
    conda params.conda_env
    publishDir "${params.outdir}/${run_id}/buckets", mode: 'copy', pattern: "*.fastq.gz"
    publishDir "${params.outdir}/${run_id}/buckets", mode: 'copy', pattern: "*.log"

    input:
    tuple val(run_id), val(sample_id), path(bkt), path(r1), path(r2)

    output:
    tuple val(run_id), val(sample_id), path("bucketize.done"), path("*.fastq.gz"), path("*.log")

    script:
    """
    "${params.scripts_dir}/bucketize_fastq.py" \\
      "$bkt" 1 3 "$r1" "${sample_id}.R1" \\
      --skip "${params.homo_sapiens_tid}" > "${sample_id}.R1.log"

    "${params.scripts_dir}/bucketize_fastq.py" \\
      "$bkt" 1 3 "$r2" "${sample_id}.R2" \\
      --skip "${params.homo_sapiens_tid}" > "${sample_id}.R2.log"

    touch bucketize.done
    """
}

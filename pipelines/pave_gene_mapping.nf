#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def normalizeSampleId(String filename) {
    def base = filename
    base = base.replaceFirst(/\.fastq(\.gz)?$/, '')
    base = base.replaceFirst(/\.R1\..*$/, '')
    base = base.replaceFirst(/_R1_.*$/, '')
    base = base.replaceFirst(/_S\d+_.*/, '')
    return base
}

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.bucket_tid_file = params.bucket_tid_file ?: "${projectRoot}/metadata/pave_bucket_tid.txt"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/config/pave_gene_mapping.multiqc.yml"

def bucketTid = params.bucket_tid
if (!bucketTid) {
    def bucketFile = new File(params.bucket_tid_file as String)
    if (!bucketFile.exists()) {
        error "bucket tid file not found: ${params.bucket_tid_file}"
    }
    def tidLine = bucketFile.readLines().find { it && !it.startsWith('#') }
    if (!tidLine) {
        error "bucket tid file is empty: ${params.bucket_tid_file}"
    }
    bucketTid = tidLine.split(/\s+/)[0].trim()
    if (!bucketTid) {
        error "bucket tid file contains no value: ${params.bucket_tid_file}"
    }
    params.bucket_tid = bucketTid
}

def requiredParams = [
    'index_dir',
    'outdir',
    'reports_dir',
    'ref_fasta',
    'index_prefix',
    'scripts_dir'
]

requiredParams.each { key ->
    if (!params[key]) {
        error "params.${key} is required"
    }
}

def checkPath(String path, String label, boolean mustBeDir = false) {
    def target = new File(path)
    if (mustBeDir) {
        if (!target.isDirectory()) {
            error "${label} is not a directory: ${path}"
        }
    } else if (!target.exists()) {
        error "${label} not found: ${path}"
    }
}

checkPath(params.ref_fasta as String, 'Reference fasta')
checkPath(params.scripts_dir as String, 'Scripts directory', true)

def indexMarker = new File("${params.index_dir}/${params.index_prefix}.1.bt2")

def indexReady = indexMarker.exists() ? Channel.value(true) : null

process CREATE_INDEX {
    tag "${params.index_prefix}"
    publishDir "${params.index_dir}", mode: 'copy', pattern: "${params.index_prefix}*"

    output:
    path "${params.index_prefix}.1.bt2", emit: marker

    script:
    """
    bowtie2-build "${params.ref_fasta}" "${params.index_prefix}"
    """
}

process MAP_SAMPLE {
    tag "${run_id}:${sample_id}"
    publishDir { "${params.outdir}/${run_id}" }, mode: 'copy'

    input:
    tuple val(run_id), val(sample_id), path(read1), path(read2), val(index_ready)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.*"), emit: mapped

    script:
    """
    set -euo pipefail
    prefix="${sample_id}"

    bowtie2 --all -x "${params.index_dir}/${params.index_prefix}" \
      -1 "${read1}" -2 "${read2}" -S "\${prefix}.sam" -p ${task.cpus}
    samtools view -S -b "\${prefix}.sam" > "\${prefix}.u.bam"
    samtools sort "\${prefix}.u.bam" -o "\${prefix}.bam" -@ ${task.cpus}
    samtools index "\${prefix}.bam"
    samtools idxstats "\${prefix}.bam" > "\${prefix}.idxstats"

    "${params.scripts_dir}/identify_top_strains.py" "\${prefix}.idxstats" > "\${prefix}.top_strains"

    samtools depth -aa "\${prefix}.bam" > "\${prefix}.depth"
    "${params.scripts_dir}/depth_stats.py" "\${prefix}.depth" "\${prefix}.depth.stats"
    """
}

process AGGREGATE_STRAINS {
    tag "aggregate_strains"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(done)

    output:
    path "strains.tsv"

    script:
    """
    "${params.scripts_dir}/aggregate_top_strains.sh" "${params.outdir}" "strains.tsv"
    """
}

process AGGREGATE_DEPTH_STATS {
    tag "aggregate_depth_stats"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(done)

    output:
    path "depth_stats.unfiltered.tsv"
    path "depth_stats.filtered.tsv"

    script:
    """
    "${params.scripts_dir}/aggregate_depth_stats.py" "${params.outdir}" \
      "depth_stats.unfiltered.tsv" -b 0 -d 0
    "${params.scripts_dir}/aggregate_depth_stats.py" "${params.outdir}" \
      "depth_stats.filtered.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.conda_env
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    path(multiqc_config)
    path(done)

    output:
    path("multiqc_report.html")

    script:
    """
    cp "${params.reports_dir}/strains.tsv" .
    cp "${params.reports_dir}/depth_stats.unfiltered.tsv" .
    cp "${params.reports_dir}/depth_stats.filtered.tsv" .

    python - <<'PY'
import csv
import os

def rewrite_with_header(src, dest, use_strain=False):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\\t')
        writer = csv.writer(out, delimiter='\\t')
        header = next(reader, None)
        if not header:
            return
        writer.writerow(['Sample'] + header)
        for row in reader:
            if not row:
                continue
            sample = row[0] if row else ''
            run = row[0] if len(row) > 0 else ''
            sid = row[1] if len(row) > 1 else ''
            strain = row[2] if len(row) > 2 else ''
            if use_strain:
                sample = f\"{run}:{sid}:{strain}\"
            else:
                sample = f\"{run}:{sid}\" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)

rewrite_with_header('strains.tsv', 'strains.multiqc.tsv')
rewrite_with_header('depth_stats.unfiltered.tsv', 'depth_stats.unfiltered.multiqc.tsv', use_strain=True)
rewrite_with_header('depth_stats.filtered.tsv', 'depth_stats.filtered.multiqc.tsv', use_strain=True)
PY

    multiqc --force \\
      --filename "multiqc_report.html" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      . "${params.outdir}" "${params.reports_dir}"
    """
}

workflow {
    def multiqc_config_path = new File(params.multiqc_config)
    if (!multiqc_config_path.exists()) {
        error "MultiQC config not found: ${params.multiqc_config}"
    }

    if (!indexReady) {
        indexReady = CREATE_INDEX().marker.map { true }
    }

    def samples
    if (params.read1 && params.read2) {
        def read1 = file(params.read1 as String)
        def read2 = file(params.read2 as String)
        if (!read1.exists()) {
            error "read1 not found: ${params.read1}"
        }
        if (!read2.exists()) {
            error "read2 not found: ${params.read2}"
        }
        def runId = params.run_id ?: "run"
        def sampleId = params.sample_id ?: normalizeSampleId(read1.getName())
        samples = Channel.of(tuple(runId, sampleId, read1, read2))
    } else if (params.reads_dir) {
        def readsDir = new File(params.reads_dir as String)
        if (!readsDir.isDirectory()) {
            error "reads_dir not found: ${params.reads_dir}"
        }
        samples = Channel.fromPath("${params.reads_dir}/*/buckets/*.R1.${bucketTid}.fastq.gz")
            .map { r1 ->
                def r2 = file(r1.toString().replace('.R1.', '.R2.'))
                if (!r2.exists()) {
                    error "missing R2 for ${r1}"
                }
                def runId = r1.getParent().getParent().getFileName().toString()
                def sampleId = normalizeSampleId(r1.getFileName().toString())
                tuple(runId, sampleId, r1, r2)
            }
        if (params.run_id) {
            samples = samples.filter { runId, sampleId, r1, r2 -> runId == params.run_id }
        }
        if (params.sample_id) {
            samples = samples.filter { runId, sampleId, r1, r2 -> sampleId == params.sample_id }
        }
        samples = samples.ifEmpty { error "no matching reads found under ${params.reads_dir}" }
    } else {
        error "set either params.read1/read2 or params.reads_dir"
    }

    def samplesWithIndex = samples.combine(indexReady)
    def mapped = MAP_SAMPLE(samplesWithIndex)
    def mappedDone = mapped.collect()

    def strains = AGGREGATE_STRAINS(mappedDone)
    def depth_stats = AGGREGATE_DEPTH_STATS(mappedDone)
    def reports_done = strains.mix(depth_stats).collect()
    def multiqc_config_channel = file(params.multiqc_config)
    MULTIQC(multiqc_config_channel, reports_done)
}

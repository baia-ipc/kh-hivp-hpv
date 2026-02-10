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
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/pave_gene_mapping.multiqc.yml"
params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: "02.pave_gene_mapping"
params.input_step_name = params.input_step_name ?: "01.bucketing"
def outdirParam = params.containsKey('outdir') ? params.outdir : null
def reportsDirParam = params.containsKey('reports_dir') ? params.reports_dir : null
def multiqcOutdirParam = params.containsKey('multiqc_outdir') ? params.multiqc_outdir : null
def multiqcReportNameParam = params.containsKey('multiqc_report_name') ? params.multiqc_report_name : null
def readsDirParam = params.containsKey('reads_dir') ? params.reads_dir : null

if (!outdirParam && params.analysis_name && params.step_name) {
    outdirParam = "${projectRoot}/outs/${params.analysis_name}/${params.step_name}"
}
if (!reportsDirParam && outdirParam) {
    reportsDirParam = "${outdirParam}/reports"
}
if (!multiqcReportNameParam) {
    multiqcReportNameParam = params.step_name \
        ? params.step_name.replace('.', '_') + ".report.html" \
        : "multiqc_report.html"
}
if ((!multiqcOutdirParam || multiqcOutdirParam.contains('unknown_analysis')) && params.analysis_name) {
    multiqcOutdirParam = "${projectRoot}/results/reports/${params.analysis_name}"
} else if (!multiqcOutdirParam) {
    multiqcOutdirParam = reportsDirParam
}
if (!readsDirParam && params.analysis_name && params.input_step_name) {
    readsDirParam = "${projectRoot}/outs/${params.analysis_name}/${params.input_step_name}"
}

params.outdir = outdirParam
params.reports_dir = reportsDirParam
params.multiqc_outdir = multiqcOutdirParam
params.multiqc_report_name = multiqcReportNameParam
params.reads_dir = readsDirParam

def requiredParams = [
    'bucket_tid',
    'bowtie_index_dir',
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

def indexMarker = new File("${params.bowtie_index_dir}/${params.index_prefix}.1.bt2")

def indexReady = indexMarker.exists() ? Channel.value(true) : null

process CREATE_INDEX {
    tag "${params.index_prefix}"
    publishDir { "${params.bowtie_index_dir}" }, mode: 'copy', pattern: "${params.index_prefix}*"

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

    bowtie2 --all -x "${params.bowtie_index_dir}/${params.index_prefix}" \
      -1 "${read1}" -2 "${read2}" -S "\${prefix}.sam" -p ${task.cpus}
    samtools view -S -b "\${prefix}.sam" > "\${prefix}.u.bam"
    samtools sort "\${prefix}.u.bam" -o "\${prefix}.bam" -@ ${task.cpus}
    samtools index "\${prefix}.bam"
    samtools idxstats "\${prefix}.bam" > "\${prefix}.idxstats"

    "${params.scripts_dir}/top_strains/identify_top_strains.py" "\${prefix}.idxstats" > "\${prefix}.top_strains"

    samtools depth -aa "\${prefix}.bam" > "\${prefix}.depth"
    "${params.scripts_dir}/coverage/depth_stats.py" "\${prefix}.depth" "\${prefix}.depth.stats"
    """
}

process AGGREGATE_STRAINS {
    tag "aggregate_strains"
    publishDir { "${params.reports_dir}" }, mode: 'copy'

    input:
    val(done)

    output:
    path "strains.tsv"

    script:
    """
    "${params.scripts_dir}/top_strains/aggregate_top_strains.sh" "${params.outdir}" "strains.tsv"
    """
}

process AGGREGATE_DEPTH_STATS {
    tag "aggregate_depth_stats"
    publishDir { "${params.reports_dir}" }, mode: 'copy'

    input:
    val(done)

    output:
    path "depth_stats.unfiltered.tsv"
    path "depth_stats.filtered.tsv"

    script:
    """
    "${params.scripts_dir}/coverage/aggregate_depth_stats.py" "${params.outdir}" \
      "depth_stats.unfiltered.tsv" -b 0 -d 0
    "${params.scripts_dir}/coverage/aggregate_depth_stats.py" "${params.outdir}" \
      "depth_stats.filtered.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.conda_env
    publishDir { "${params.multiqc_outdir}" }, mode: 'copy'

    input:
    path(multiqc_config)
    path(done)

    output:
    path("${params.multiqc_report_name}")

    script:
    """
    cp "${params.reports_dir}/strains.tsv" .
    cp "${params.reports_dir}/depth_stats.unfiltered.tsv" .
    cp "${params.reports_dir}/depth_stats.filtered.tsv" .

    python "${params.scripts_dir}/coverage/prepare_pave_multiqc_inputs.py" \\
      --strains "strains.tsv" --strains-out "strains.multiqc.tsv" \\
      --depth-unfiltered "depth_stats.unfiltered.tsv" --depth-unfiltered-out "depth_stats.unfiltered.multiqc.tsv" \\
      --depth-filtered "depth_stats.filtered.tsv" --depth-filtered-out "depth_stats.filtered.multiqc.tsv"

    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
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

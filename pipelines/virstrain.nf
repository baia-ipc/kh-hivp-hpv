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
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/virstrain.multiqc.yml"
params.run_virstrain = params.run_virstrain ?: false
params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: "04.virstrain"
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
if (!params.containsKey('read1')) params.read1 = null
if (!params.containsKey('read2')) params.read2 = null
if (!params.containsKey('run_id')) params.run_id = null
if (!params.containsKey('sample_id')) params.sample_id = null

def requiredParams = [
    'bucket_tid',
    'virstrain_index_dir',
    'outdir',
    'reports_dir',
    'ref_fasta',
    'scripts_dir'
]

requiredParams.each { key ->
    if (params.run_virstrain && !params[key]) {
        error "params.${key} is required"
    }
}

def bucketTid = params.bucket_tid

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

if (params.run_virstrain) {
    checkPath(params.ref_fasta as String, 'VirStrain reference fasta')
    checkPath(params.scripts_dir as String, 'Scripts directory', true)
}

def indexMarker = new File("${params.virstrain_index_dir}/virstrain")

def indexReady = indexMarker.isDirectory() ? Channel.value(true) : null

process CREATE_INDEX {
    tag "virstrain"
    conda params.conda_env
    publishDir { "${params.virstrain_index_dir}" }, mode: 'copy'

    output:
    path "virstrain", emit: marker
    path "pave_hsa.fas"
    path "pave_hsa.msa.fas"
    path "pave_hsa.msa.virstrain.fas"

    script:
    """
    ln -sf "${params.ref_fasta}" pave_hsa.fas
    mafft --auto pave_hsa.fas > pave_hsa.msa.fas
    "${params.scripts_dir}/phylo_tree/fix_msa_formatting.py" pave_hsa.msa.fas > pave_hsa.msa.virstrain.fas
    virstrain_build -i pave_hsa.msa.virstrain.fas -d virstrain
    """
}

process RUN_VIRSTRAIN {
    tag "${run_id}:${sample_id}"
    conda params.conda_env
    publishDir { "${params.outdir}/${run_id}" }, mode: 'copy'

    input:
    tuple val(run_id), val(sample_id), path(read1), path(read2), val(index_ready)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}"), emit: results

    script:
    """
    set -euo pipefail
    mkdir -p "${sample_id}"
    virstrain \
      -i "${read1}" \
      -p "${read2}" \
      -d "${params.virstrain_index_dir}/virstrain" \
      -o "${sample_id}"
    """
}

process AGGREGATE_RESULTS {
    tag "aggregate_virstrain"
    conda params.conda_env
    publishDir { "${params.reports_dir}" }, mode: 'copy'

    input:
    val(done)

    output:
    path "strains.tsv"

    script:
    """
    "${params.scripts_dir}/virstrain/aggregate_virstrain_results.py" "${params.outdir}" > "strains.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.multiqc_env
    publishDir { "${params.multiqc_outdir}" }, mode: 'copy'

    input:
    path(multiqc_config)
    path(done)

    output:
    path("${params.multiqc_report_name}")

    script:
    """
    cp "${params.reports_dir}/strains.tsv" .

    python "${params.scripts_dir}/virstrain/prepare_virstrain_multiqc_inputs.py" \\
      --strains "strains.tsv" --out "strains.multiqc.tsv"

    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      . "${params.outdir}" "${params.reports_dir}"
    """
}

workflow {
    if (!params.run_virstrain) {
        log.info "VirStrain run disabled (set --run-virstrain to enable)."
        return
    }
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
    def mapped = RUN_VIRSTRAIN(samplesWithIndex)
    def mappedDone = mapped.collect()

    def strains = AGGREGATE_RESULTS(mappedDone)
    def multiqc_config_channel = file(params.multiqc_config)
    MULTIQC(multiqc_config_channel, strains.collect())
}

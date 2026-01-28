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
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/config/virstrain.multiqc.yml"

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

checkPath(params.ref_fasta as String, 'VirStrain reference fasta')
checkPath(params.scripts_dir as String, 'Scripts directory', true)

def indexMarker = new File("${params.index_dir}/virstrain")

def indexReady = indexMarker.isDirectory() ? Channel.value(true) : null

process CREATE_INDEX {
    tag "virstrain"
    publishDir "${params.index_dir}", mode: 'copy'

    output:
    path "virstrain", emit: marker
    path "pave_hsa.fas"
    path "pave_hsa.msa.fas"
    path "pave_hsa.msa.virstrain.fas"

    script:
    """
    ln -sf "${params.ref_fasta}" pave_hsa.fas
    mafft --auto pave_hsa.fas > pave_hsa.msa.fas
    "${params.scripts_dir}/fix_msa_formatting.py" pave_hsa.msa.fas > pave_hsa.msa.virstrain.fas
    virstrain_build -i pave_hsa.msa.virstrain.fas -d virstrain
    """
}

process RUN_VIRSTRAIN {
    tag "${run_id}:${sample_id}"
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
      -d "${params.index_dir}/virstrain" \
      -o "${sample_id}"
    """
}

process AGGREGATE_RESULTS {
    tag "aggregate_virstrain"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(done)

    output:
    path "strains.tsv"

    script:
    """
    "${params.scripts_dir}/aggregate_results.py" "${params.outdir}" > "strains.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.multiqc_env
    publishDir "${params.reports_dir}/multiqc", mode: 'copy'

    input:
    path(multiqc_config)
    path(done)

    output:
    path("multiqc_report.html")

    script:
    """
    cp "${params.reports_dir}/strains.tsv" .

    python - <<'PY'
import csv
import os

header = ['run', 'sample', 'strains']

if os.path.exists('strains.tsv'):
    with open('strains.tsv', newline='') as inp, open('strains.multiqc.tsv', 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\\t')
        writer = csv.writer(out, delimiter='\\t')
        first = next(reader, None)
        if first:
            if len(first) != len(header):
                header = header + [f\"col{i}\" for i in range(len(header) + 1, len(first) + 1)]
            writer.writerow(['Sample'] + header[:len(first)])
            sample = f\"{first[0]}:{first[1]}\" if len(first) > 1 else first[0]
            writer.writerow([sample] + first)
            for row in reader:
                if not row:
                    continue
                sample = f\"{row[0]}:{row[1]}\" if len(row) > 1 else row[0]
                writer.writerow([sample] + row)
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
    def mapped = RUN_VIRSTRAIN(samplesWithIndex)
    def mappedDone = mapped.collect()

    def strains = AGGREGATE_RESULTS(mappedDone)
    def multiqc_config_channel = file(params.multiqc_config)
    MULTIQC(multiqc_config_channel, strains.collect())
}

#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

include { CENTRIFUGE_BUCKETING } from './centrifuge_bucketing.nf'

def normalizeSampleId(String filename) {
    def base = filename
    base = base.replaceFirst(/\.fastq(\.gz)?$/, '')
    base = base.replaceFirst(/_R[12].*/, '')
    base = base.replaceFirst(/_S\d+_.*/, '')
    return base
}

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

// Define optional params exactly once to avoid Nextflow "undefined parameter" and "defined multiple times" warnings.
if (!params.containsKey('samples_tsv') || !params.samples_tsv) {
    params.samples_tsv = "${projectRoot}/metadata/samples-input1.tsv"
}
if (!params.containsKey('reports_dir') || !params.reports_dir) {
    params.reports_dir = "${projectRoot}/analysis-input1/001.0.centrifuge/reports"
}
if (!params.containsKey('aggregate_skip_wo_human') || !params.aggregate_skip_wo_human) {
    params.aggregate_skip_wo_human = "9606,2886930,2759"
}
if (!params.containsKey('aggregate_skip') || !params.aggregate_skip) {
    params.aggregate_skip = "2886930,2759"
}
params.outdir = params.outdir ?: "${projectRoot}/analysis-input1/001.0.centrifuge/output"
if (!params.containsKey('precomputed_root') || !params.precomputed_root) {
    params.precomputed_root = params.outdir
}
params.buckets = params.buckets ?: "${projectRoot}/metadata/bucket_taxonomy_ids.tsv"
params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/config/centrifuge_bucketing.env.yml"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/config/centrifuge_bucketing.multiqc.yml"
params.index = params.index ?: "/srv/databases/centrifuge/hpvc/latest/hpvc"
params.taxdump = params.taxdump ?: "/srv/databases/centrifuge/hpvc/latest/factory/taxonomy-2023-10-30"
params.homo_sapiens_tid = params.homo_sapiens_tid ?: 9606
params.threads = params.threads ?: 64

def loadSamples(String samplesPath) {
    def samplesFile = new File(samplesPath)
    if (!samplesFile.exists()) {
        error "samples file not found: ${samplesPath}"
    }
    def rows = samplesFile.readLines()
        .findAll { it && !it.startsWith('#') }
        .collect { it.split('\t') as List }
    rows.eachWithIndex { cols, idx ->
        if (cols.size() < 3) {
            error "invalid line ${idx + 1} in ${samplesPath}: ${cols.join('\t')}"
        }
    }
    return rows
}

def findReadPair(String fastqDir, String samplePrefix) {
    def dir = new File(fastqDir)
    if (!dir.isDirectory()) {
        error "fastq directory not found: ${fastqDir}"
    }
    def r1 = dir.listFiles().findAll {
        it.name.startsWith(samplePrefix) &&
        it.name.contains('_R1_') &&
        it.name.endsWith('.fastq.gz')
    }
    def r2 = dir.listFiles().findAll {
        it.name.startsWith(samplePrefix) &&
        it.name.contains('_R2_') &&
        it.name.endsWith('.fastq.gz')
    }
    if (r1.size() != 1 || r2.size() != 1) {
        error "expected 1 R1/R2 for ${samplePrefix} in ${fastqDir}, got ${r1.size()} R1 and ${r2.size()} R2"
    }
    return [r1[0], r2[0]]
}

process AGGREGATE_COUNTS {
    tag "aggregate"

    input:
    val(done)

    output:
    path("aggregate.done")

    script:
    """
    "${params.scripts_dir}/aggregate_bucket_counts.py" --skip "${params.aggregate_skip_wo_human}" \\
      --no-abs --rel-fname relative_counts.wo_human.tsv \\
      "${params.buckets}" "${params.outdir}" "${params.reports_dir}"

    "${params.scripts_dir}/aggregate_bucket_counts.py" --skip "${params.aggregate_skip}" \\
      "${params.buckets}" "${params.outdir}" "${params.reports_dir}"

    touch aggregate.done
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.conda_env
    publishDir "${params.reports_dir}/multiqc", mode: 'copy'

    input:
    path(multiqc_config)
    path(done)

    output:
    path("multiqc_report.html")

    script:
    """
    cp "${params.reports_dir}/absolute_counts.tsv" .
    cp "${params.reports_dir}/relative_counts.tsv" .
    cp "${params.reports_dir}/relative_counts.wo_human.tsv" .

    multiqc --force \\
      --config "${multiqc_config}" \\
      --outdir . \\
      "${params.outdir}" "${params.reports_dir}"
    """
}

workflow {
    def rows = loadSamples(params.samples_tsv)
    if (!rows) {
        error "no samples found in ${params.samples_tsv}"
    }
    def multiqc_config_file = new File(params.multiqc_config)
    if (!multiqc_config_file.exists()) {
        error "MultiQC config not found: ${params.multiqc_config}"
    }

    reads_ch = Channel.from(rows)
        .map { cols ->
            def fastq_dir = cols[1]
            def sample_prefix = cols[2]
            def fastq_path = new File(projectRoot, fastq_dir).getPath()
            def (r1File, r2File) = findReadPair(fastq_path, sample_prefix)
            def sample_id = sample_prefix
            def run_id = new File(fastq_path).getParentFile().getName()
            tuple(run_id, sample_id, file(r1File.absolutePath), file(r2File.absolutePath))
        }

    bucketized = CENTRIFUGE_BUCKETING(reads_ch)
    aggregate_done = AGGREGATE_COUNTS(bucketized.collect())
    def multiqc_config_file = file(params.multiqc_config)
    MULTIQC(multiqc_config_file, aggregate_done)
}

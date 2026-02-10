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

params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: "01.bucketing"
def outdirParam = params.containsKey('outdir') ? params.outdir : null
def reportsDirParam = params.containsKey('reports_dir') ? params.reports_dir : null
def multiqcOutdirParam = params.containsKey('multiqc_outdir') ? params.multiqc_outdir : null
def multiqcReportNameParam = params.containsKey('multiqc_report_name') ? params.multiqc_report_name : null

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

params.outdir = outdirParam
params.reports_dir = reportsDirParam
params.multiqc_outdir = multiqcOutdirParam
params.multiqc_report_name = multiqcReportNameParam

def requiredParams = [
    'samples_tsv',
    'reports_dir',
    'outdir',
    'buckets',
    'scripts_dir',
    'multiqc_config',
    'index',
    'taxdump',
    'homo_sapiens_tid',
    'threads',
    'aggregate_skip',
    'conda_env'
]

requiredParams.each { key ->
    if (!params.containsKey(key) || params[key] == null || params[key].toString().trim().isEmpty()) {
        error "params.${key} is required"
    }
}

if (!params.containsKey('skip_align') || params.skip_align == null) {
    params.skip_align = false
}
if (!params.containsKey('precomputed_root') || !params.precomputed_root) {
    params.precomputed_root = params.outdir
}
if (!params.containsKey('precomputed_run_id')) {
    params.precomputed_run_id = null
}

def aggregateSkipList = params.aggregate_skip.toString()
    .split(',')
    .collect { it.trim() }
    .findAll { it }
def homoTid = params.homo_sapiens_tid.toString().trim()
def skipNoHuman = ([homoTid] + aggregateSkipList.findAll { it != homoTid }).unique()
params.aggregate_skip_wo_human = skipNoHuman.join(',')

def precomputedRunDirs = []
if (params.skip_align) {
    def precomputedRootDir = new File(params.precomputed_root as String)
    if (precomputedRootDir.isDirectory()) {
        precomputedRunDirs = precomputedRootDir.listFiles()
            ?.findAll { it.isDirectory() && it.name != 'reports' }
            ?.collect { it.name }
            ?: []
    }
}

def resolveRunIdForSample = { String inferredRunId, String tsvRunId ->
    if (params.skip_align && params.precomputed_run_id) {
        return params.precomputed_run_id.toString()
    }
    if (!params.skip_align || precomputedRunDirs.isEmpty()) {
        return inferredRunId
    }
    if (precomputedRunDirs.size() == 1) {
        return precomputedRunDirs[0]
    }
    if (precomputedRunDirs.contains(inferredRunId)) {
        return inferredRunId
    }
    def cleanTsvRunId = tsvRunId?.trim()
    if (cleanTsvRunId) {
        def escaped = java.util.regex.Pattern.quote(cleanTsvRunId)
        def matches = precomputedRunDirs.findAll { dirName ->
            dirName == cleanTsvRunId || dirName ==~ /.*(?:run)?0*${escaped}$/
        }
        if (matches.size() == 1) {
            return matches[0]
        }
    }
    return inferredRunId
}

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

def resolveFastqDir(String fastqDir) {
    def dir = new File(fastqDir)
    if (dir.isDirectory()) {
        return dir
    }
    def lower = fastqDir.toLowerCase()
    if (lower.endsWith('/fastq')) {
        def parent = dir.getParentFile()
        if (parent != null && parent.isDirectory()) {
            return parent
        }
    }
    def withFastq = new File(fastqDir, 'Fastq')
    if (withFastq.isDirectory()) {
        return withFastq
    }
    def withfastq = new File(fastqDir, 'fastq')
    if (withfastq.isDirectory()) {
        return withfastq
    }
    error "fastq directory not found: ${fastqDir}"
}

def findReadPair(File dir, String samplePrefix) {
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
        error "expected 1 R1/R2 for ${samplePrefix} in ${dir}, got ${r1.size()} R1 and ${r2.size()} R2"
    }
    return [r1[0], r2[0]]
}

process AGGREGATE_COUNTS {
    tag "aggregate"

    input:
    val(done_entries)

    output:
    path("aggregate.done")

    script:
    """
    prev_count=-1
    stable_rounds=0
    actual_count=0
    for _ in {1..180}; do
      actual_count=`find "${params.outdir}" -mindepth 3 -maxdepth 3 -type f -path "*/bucket_sizes/*.bsz.tsv" | wc -l`
      if [ "\$actual_count" -eq "\$prev_count" ]; then
        stable_rounds=\$((stable_rounds + 1))
      else
        stable_rounds=0
      fi
      prev_count="\$actual_count"

      if [ "\$actual_count" -gt 0 ] && [ "\$stable_rounds" -ge 3 ]; then
        break
      fi
      sleep 2
    done

    if [ "\$actual_count" -eq 0 ]; then
      echo "ERROR: no bucket size files found under ${params.outdir}" >&2
      exit 1
    fi

    "${params.scripts_dir}/taxonomy_assignment/aggregate_bucket_counts.py" --skip "${params.aggregate_skip_wo_human}" \\
      --no-abs --rel-fname relative_counts.wo_human.tsv \\
      "${params.buckets}" "${params.outdir}" "${params.reports_dir}"

    "${params.scripts_dir}/taxonomy_assignment/aggregate_bucket_counts.py" --skip "${params.aggregate_skip}" \\
      "${params.buckets}" "${params.outdir}" "${params.reports_dir}"

    touch aggregate.done
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
    cp "${params.reports_dir}/absolute_counts.tsv" .
    cp "${params.reports_dir}/relative_counts.tsv" .
    cp "${params.reports_dir}/relative_counts.wo_human.tsv" .

    python "${params.scripts_dir}/taxonomy_assignment/prepare_centrifuge_multiqc_inputs.py" \\
      --absolute "absolute_counts.tsv" --absolute-out "absolute_counts.multiqc.tsv" \\
      --relative "relative_counts.tsv" --relative-out "relative_counts.multiqc.tsv" \\
      --relative-wo-human "relative_counts.wo_human.tsv" --relative-wo-human-out "relative_counts.wo_human.multiqc.tsv"

    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      . "${params.outdir}" "${params.reports_dir}"
    """
}

workflow {
    def rows = loadSamples(params.samples_tsv)
    if (!rows) {
        error "no samples found in ${params.samples_tsv}"
    }
    def multiqc_config_path = new File(params.multiqc_config)
    if (!multiqc_config_path.exists()) {
        error "MultiQC config not found: ${params.multiqc_config}"
    }

    reads_ch = Channel.from(rows)
        .map { cols ->
            def tsv_run_id = cols[0]
            def fastq_dir = cols[1]
            def sample_prefix = cols[2]
            def fastq_prefix = (cols.size() > 3 && cols[3]) ? cols[3] : sample_prefix
            def fastq_path = new File(projectRoot, fastq_dir).getPath()
            def resolvedDir = resolveFastqDir(fastq_path)
            def (r1File, r2File) = findReadPair(resolvedDir, fastq_prefix)
            def sample_id = sample_prefix
            def inferred_run_id = resolvedDir.getName().equalsIgnoreCase('fastq') \
                ? resolvedDir.getParentFile().getName() \
                : resolvedDir.getName()
            def run_id = resolveRunIdForSample(inferred_run_id, tsv_run_id)
            tuple(run_id, sample_id, file(r1File.absolutePath), file(r2File.absolutePath))
        }

    def centrifuge = CENTRIFUGE_BUCKETING(reads_ch)
    def bucketized = centrifuge.bucketized
    aggregate_done = AGGREGATE_COUNTS(bucketized.collect())
    def multiqc_config_file = file(params.multiqc_config)
    MULTIQC(multiqc_config_file, aggregate_done)
}

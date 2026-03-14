#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/pipelines/conda_env/recombination.env.yml"
params.multiqc_env = params.multiqc_env ?: "${projectRoot}/.conda/envs/pipeline"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/recombination_analysis.multiqc.yml"

params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: "06.recombination_analysis"
params.input_step_name = params.input_step_name ?: "03.variant_analysis"

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
    multiqcReportNameParam = params.step_name
        ? params.step_name.replace('.', '_') + ".report.html"
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

params.recombination_input_mode = params.recombination_input_mode ?: "metadata_fasta"
params.recombination_sequences_tsv = params.containsKey('recombination_sequences_tsv') ? params.recombination_sequences_tsv : null
params.recombination_exclude_samples_tsv = params.containsKey('recombination_exclude_samples_tsv') ? params.recombination_exclude_samples_tsv : null
params.recombination_hpv_types = params.containsKey('recombination_hpv_types') ? params.recombination_hpv_types : null
params.recombination_skip_controls = params.containsKey('recombination_skip_controls') ? params.recombination_skip_controls : true
params.recombination_control_pattern = params.containsKey('recombination_control_pattern') ? params.recombination_control_pattern : '^(H2O|HPV-110|Ex|HPV-19|Undetermined.*)$'

params.recombination_input_is_aligned = params.containsKey('recombination_input_is_aligned') ? params.recombination_input_is_aligned : false
params.recombination_min_sequences = params.containsKey('recombination_min_sequences') ? params.recombination_min_sequences : 3
params.recombination_mafft_args = params.recombination_mafft_args ?: "--auto"

params.recombination_gard_model = params.recombination_gard_model ?: "012345"
params.recombination_gard_rate_classes = params.containsKey('recombination_gard_rate_classes') ? params.recombination_gard_rate_classes : 3
params.recombination_gard_max_breakpoints = params.containsKey('recombination_gard_max_breakpoints') ? params.recombination_gard_max_breakpoints : 10
params.recombination_gard_confidence = params.recombination_gard_confidence ?: "low"

params.recombination_enable_similarity_plot = params.containsKey('recombination_enable_similarity_plot') ? params.recombination_enable_similarity_plot : true

params.prepare_sequences_script = (params.containsKey('prepare_sequences_script') && params.prepare_sequences_script) ? params.prepare_sequences_script : "${params.scripts_dir}/recombination/prepare_recombination_inputs.py"
params.gard_runner_script = (params.containsKey('gard_runner_script') && params.gard_runner_script) ? params.gard_runner_script : "${params.scripts_dir}/recombination/run_hyphy_gard.sh"
params.gard_parser_script = (params.containsKey('gard_parser_script') && params.gard_parser_script) ? params.gard_parser_script : "${params.scripts_dir}/recombination/parse_gard_json.py"
params.summary_script = (params.containsKey('summary_script') && params.summary_script) ? params.summary_script : "${params.scripts_dir}/recombination/summarize_recombination.py"
params.plot_script = (params.containsKey('plot_script') && params.plot_script) ? params.plot_script : "${params.scripts_dir}/recombination/plot_alignment_similarity.py"

if (!params.outdir) error "params.outdir is required"
if (!params.reports_dir) error "params.reports_dir is required"
if (!params.recombination_sequences_tsv) error "params.recombination_sequences_tsv is required"
if (params.recombination_input_mode != "metadata_fasta") {
    error "Unsupported recombination_input_mode='${params.recombination_input_mode}'. Only 'metadata_fasta' is currently supported."
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

checkPath(params.recombination_sequences_tsv as String, 'Recombination sequence TSV')
if (params.recombination_exclude_samples_tsv) {
    checkPath(params.recombination_exclude_samples_tsv as String, 'Recombination exclude samples list')
}
checkPath(params.prepare_sequences_script as String, 'Prepare sequences script')
checkPath(params.gard_runner_script as String, 'GARD runner script')
checkPath(params.gard_parser_script as String, 'GARD parser script')
checkPath(params.summary_script as String, 'Recombination summary script')
checkPath(params.plot_script as String, 'Recombination plot script')


def multiqcConfigFile = file(params.multiqc_config)
if (!multiqcConfigFile.exists()) {
    error "MultiQC config not found: ${params.multiqc_config}"
}

process PREPARE_SEQUENCES {
    tag "prepare_sequences"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_input_*"
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "excluded_samples.tsv"

    input:
    path(sequence_table)

    output:
    path "recombination_input.fasta", emit: fasta
    path "recombination_input_manifest.tsv", emit: manifest
    path "excluded_samples.tsv", emit: excluded
    path "input_summary.json", emit: summary_json

    script:
    def excludeFlag = params.recombination_exclude_samples_tsv ? "--exclude-samples-tsv \"${params.recombination_exclude_samples_tsv}\"" : ""
    def hpvFlag = params.recombination_hpv_types ? "--hpv-types \"${params.recombination_hpv_types}\"" : ""
    def controlFlags = params.recombination_skip_controls
        ? "--skip-controls --exclude-pattern \"${params.recombination_control_pattern}\""
        : ""
    def optionalArgs = [excludeFlag, hpvFlag, controlFlags].findAll { it }.join(' ')
    """
    python3 "${params.prepare_sequences_script}" \\
      --sequences-tsv "${sequence_table}" \\
      --output-fasta "recombination_input.fasta" \\
      --output-manifest "recombination_input_manifest.tsv" \\
      --output-excluded "excluded_samples.tsv" \\
      --output-summary-json "input_summary.json" \\
      --repo-root "${projectRoot}" \\
      --min-sequences "${params.recombination_min_sequences}" \\
      ${optionalArgs}
    """
}

process ALIGN_MAFFT {
    tag "alignment"
    conda params.conda_env
    publishDir { "${params.outdir}/alignment" }, mode: 'copy'

    input:
    path(input_fasta)

    output:
    path "recombination.aln.fasta", emit: alignment

    script:
    """
    mafft ${params.recombination_mafft_args} "${input_fasta}" > recombination.aln.fasta
    """
}

process PASSTHROUGH_ALIGNMENT {
    tag "alignment_passthrough"
    conda params.conda_env
    publishDir { "${params.outdir}/alignment" }, mode: 'copy'

    input:
    path(input_fasta)

    output:
    path "recombination.aln.fasta", emit: alignment

    script:
    """
    cp "${input_fasta}" recombination.aln.fasta
    """
}

process GARD_BREAKPOINTS {
    tag "gard"
    conda params.conda_env
    publishDir { "${params.outdir}/gard" }, mode: 'copy'

    input:
    path(alignment)

    output:
    path "gard.json", emit: gard_json
    path "gard.breakpoints.tsv", emit: breakpoints
    path "gard.summary.json", emit: summary
    path "gard.warnings.tsv", emit: warnings
    path "gard.log", emit: log

    script:
    """
    bash "${params.gard_runner_script}" \\
      "${alignment}" \\
      "gard.json" \\
      "gard.log" \\
      "${params.recombination_gard_model}" \\
      "${params.recombination_gard_rate_classes}" \\
      "${params.recombination_gard_max_breakpoints}"

    python3 "${params.gard_parser_script}" \\
      --input-json "gard.json" \\
      --output-breakpoints-tsv "gard.breakpoints.tsv" \\
      --output-summary-json "gard.summary.json" \\
      --output-warnings-tsv "gard.warnings.tsv"
    """
}

process RECOMBINATION_SUMMARY {
    tag "summary"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy'
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_events.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_summary.md"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_summary.multiqc.tsv"

    input:
    path(manifest)
    path(excluded)
    path(gard_breakpoints)
    path(gard_summary)

    output:
    path "recombination_events.tsv", emit: events_tsv
    path "recombination_events.csv", emit: events_csv
    path "recombination_events.json", emit: events_json
    path "recombination_summary.md", emit: summary_md
    path "recombination_warnings.tsv", emit: warnings_tsv
    path "recombination_summary.multiqc.tsv", emit: multiqc_tsv

    script:
    """
    python3 "${params.summary_script}" \\
      --manifest-tsv "${manifest}" \\
      --excluded-tsv "${excluded}" \\
      --gard-breakpoints-tsv "${gard_breakpoints}" \\
      --gard-summary-json "${gard_summary}" \\
      --output-events-tsv "recombination_events.tsv" \\
      --output-events-csv "recombination_events.csv" \\
      --output-events-json "recombination_events.json" \\
      --output-summary-md "recombination_summary.md" \\
      --output-warnings-tsv "recombination_warnings.tsv" \\
      --output-multiqc-tsv "recombination_summary.multiqc.tsv" \\
      --gard-support-confidence "${params.recombination_gard_confidence}"
    """
}

process SIMILARITY_PLOTS {
    tag "similarity_plots"
    conda params.conda_env
    publishDir { "${params.outdir}/plots" }, mode: 'copy'

    input:
    path(alignment)

    output:
    path "pairwise_identity.tsv", emit: pairwise_tsv
    path "pairwise_identity.png", emit: pairwise_png
    path "plot.warnings.tsv", emit: plot_warnings

    script:
    """
    python3 "${params.plot_script}" \\
      --alignment "${alignment}" \\
      --output-tsv "pairwise_identity.tsv" \\
      --output-png "pairwise_identity.png" \\
      --output-warnings "plot.warnings.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.multiqc_env
    publishDir { "${params.multiqc_outdir}" }, mode: 'copy', pattern: "${params.multiqc_report_name}"

    input:
    path(multiqc_config)
    path(summary_multiqc)
    path(summary_md)

    output:
    path("${params.multiqc_report_name}")

    script:
    """
    cp "${summary_multiqc}" .
    cp "${summary_md}" .

    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      . "${params.outdir}" "${params.reports_dir}"
    """
}

workflow {
    def sequenceTable = file(params.recombination_sequences_tsv as String)
    if (!sequenceTable.exists()) {
        error "recombination_sequences_tsv not found: ${params.recombination_sequences_tsv}"
    }

    def prepared = PREPARE_SEQUENCES(Channel.of(sequenceTable))

    def aligned = params.recombination_input_is_aligned
        ? PASSTHROUGH_ALIGNMENT(prepared.fasta).alignment
        : ALIGN_MAFFT(prepared.fasta).alignment

    def gard = GARD_BREAKPOINTS(aligned)
    def summary = RECOMBINATION_SUMMARY(prepared.manifest, prepared.excluded, gard.breakpoints, gard.summary)

    if (params.recombination_enable_similarity_plot) {
        SIMILARITY_PLOTS(aligned)
    }

    MULTIQC(multiqcConfigFile, summary.multiqc_tsv, summary.summary_md)
}

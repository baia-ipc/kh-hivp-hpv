#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/pipelines/conda_env/recombination.env.yml"
params.openrdp_conda_env = params.openrdp_conda_env ?: "${projectRoot}/pipelines/conda_env/recombination.openrdp.env.yml"
params.multiqc_env = params.multiqc_env ?: "${projectRoot}/.conda/envs/pipeline"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/recombination_confirmation.multiqc.yml"

params.recombination_stage = params.containsKey('recombination_stage') ? params.recombination_stage : "confirmation"
params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: (
    params.recombination_stage == "screen"
        ? "06.recombination_screen"
        : params.recombination_stage == "openrdp"
            ? "07.recombination_openrdp"
            : params.recombination_stage == "3seq"
                ? "07.recombination_3seq"
                : params.recombination_stage == "geneconv"
                    ? "07.recombination_geneconv"
            : "08.recombination_confirmation"
)
params.input_step_name = params.input_step_name ?: (
    params.recombination_stage == "screen"
        ? "03.variant_analysis"
        : params.recombination_stage == "openrdp"
            ? "06.recombination_screen"
            : params.recombination_stage == "3seq"
                ? "06.recombination_screen"
                : params.recombination_stage == "geneconv"
                    ? "06.recombination_screen"
            : "07.recombination_openrdp"
)

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
params.recombination_screen_groups_tsv = params.containsKey('recombination_screen_groups_tsv')
    ? params.recombination_screen_groups_tsv
    : (params.analysis_name ? "${projectRoot}/outs/${params.analysis_name}/06.recombination_screen/summary/recombination_screen_groups.tsv" : null)
params.recombination_openrdp_groups_tsv = params.containsKey('recombination_openrdp_groups_tsv')
    ? params.recombination_openrdp_groups_tsv
    : (params.analysis_name ? "${projectRoot}/outs/${params.analysis_name}/07.recombination_openrdp/summary/recombination_openrdp_groups.tsv" : null)
params.recombination_3seq_groups_tsv = params.containsKey('recombination_3seq_groups_tsv')
    ? params.recombination_3seq_groups_tsv
    : (params.analysis_name ? "${projectRoot}/outs/${params.analysis_name}/07.recombination_3seq/summary/recombination_3seq_groups.tsv" : null)
params.recombination_geneconv_groups_tsv = params.containsKey('recombination_geneconv_groups_tsv')
    ? params.recombination_geneconv_groups_tsv
    : (params.analysis_name ? "${projectRoot}/outs/${params.analysis_name}/07.recombination_geneconv/summary/recombination_geneconv_groups.tsv" : null)

params.recombination_input_mode = params.recombination_input_mode ?: "metadata_fasta"
params.recombination_sequences_tsv = params.containsKey('recombination_sequences_tsv') ? params.recombination_sequences_tsv : null
params.recombination_exclude_samples_tsv = params.containsKey('recombination_exclude_samples_tsv') ? params.recombination_exclude_samples_tsv : null
params.recombination_hpv_types = params.containsKey('recombination_hpv_types') ? params.recombination_hpv_types : null
params.recombination_skip_controls = params.containsKey('recombination_skip_controls') ? params.recombination_skip_controls : true
params.recombination_control_pattern = params.containsKey('recombination_control_pattern') ? params.recombination_control_pattern : '^(H2O|HPV-110|Ex|HPV-19|Undetermined.*)$'

params.recombination_input_is_aligned = params.containsKey('recombination_input_is_aligned') ? params.recombination_input_is_aligned : false
params.recombination_min_sequences = params.containsKey('recombination_min_sequences') ? params.recombination_min_sequences : 3
params.recombination_mafft_args = params.recombination_mafft_args ?: "--auto"
params.recombination_split_by_hpv_type = params.containsKey('recombination_split_by_hpv_type') ? params.recombination_split_by_hpv_type : true
params.recombination_background_mode = params.recombination_background_mode ?: "tree_selected_same_type"
params.recombination_hpv16_background_fasta = params.containsKey('recombination_hpv16_background_fasta') ? params.recombination_hpv16_background_fasta : "${projectRoot}/derived_data/refdata/hpv16_tree/selected_renamed.fasta"
params.recombination_hpv18_background_fasta = params.containsKey('recombination_hpv18_background_fasta') ? params.recombination_hpv18_background_fasta : "${projectRoot}/derived_data/refdata/hpv18_tree/selected_renamed.fasta"

params.recombination_gard_model = params.recombination_gard_model ?: "012345"
params.recombination_gard_rate_classes = params.containsKey('recombination_gard_rate_classes') ? params.recombination_gard_rate_classes : 3
params.recombination_gard_max_breakpoints = params.containsKey('recombination_gard_max_breakpoints') ? params.recombination_gard_max_breakpoints : 10
params.recombination_gard_confidence = params.recombination_gard_confidence ?: "low"
params.recombination_enable_gard = params.containsKey('recombination_enable_gard')
    ? params.recombination_enable_gard
    : false

params.recombination_enable_openrdp = params.containsKey('recombination_enable_openrdp')
    ? params.recombination_enable_openrdp
    : true
params.recombination_openrdp_methods = params.containsKey('recombination_openrdp_methods')
    ? params.recombination_openrdp_methods
    : "geneconv bootscan siscan chimaera rdp"
params.recombination_openrdp_pvalue_threshold = params.containsKey('recombination_openrdp_pvalue_threshold')
    ? params.recombination_openrdp_pvalue_threshold
    : 0.01
params.recombination_openrdp_min_segment_length = params.containsKey('recombination_openrdp_min_segment_length')
    ? params.recombination_openrdp_min_segment_length
    : 500
params.recombination_openrdp_combined_timeout_seconds = params.containsKey('recombination_openrdp_combined_timeout_seconds')
    ? params.recombination_openrdp_combined_timeout_seconds
    : 28800
params.recombination_openrdp_method_timeout_seconds = params.containsKey('recombination_openrdp_method_timeout_seconds')
    ? params.recombination_openrdp_method_timeout_seconds
    : 14400
params.recombination_3seq_pvalue_threshold = params.containsKey('recombination_3seq_pvalue_threshold')
    ? params.recombination_3seq_pvalue_threshold
    : 0.05
params.recombination_3seq_min_segment_length = params.containsKey('recombination_3seq_min_segment_length')
    ? params.recombination_3seq_min_segment_length
    : 0
params.recombination_geneconv_pvalue_threshold = params.containsKey('recombination_geneconv_pvalue_threshold')
    ? params.recombination_geneconv_pvalue_threshold
    : 0.05
params.recombination_geneconv_min_segment_length = params.containsKey('recombination_geneconv_min_segment_length')
    ? params.recombination_geneconv_min_segment_length
    : 0
params.recombination_3seq_timeout_seconds = params.containsKey('recombination_3seq_timeout_seconds')
    ? params.recombination_3seq_timeout_seconds
    : 14400
params.recombination_geneconv_timeout_seconds = params.containsKey('recombination_geneconv_timeout_seconds')
    ? params.recombination_geneconv_timeout_seconds
    : 14400

params.recombination_tree_min_bootstrap = params.containsKey('recombination_tree_min_bootstrap') ? params.recombination_tree_min_bootstrap : 95
params.recombination_tree_bootstrap_replicates = params.containsKey('recombination_tree_bootstrap_replicates') ? params.recombination_tree_bootstrap_replicates : 1000
params.recombination_iqtree_bin = params.containsKey('recombination_iqtree_bin') ? params.recombination_iqtree_bin : "iqtree"
params.recombination_iqtree_model = params.containsKey('recombination_iqtree_model') ? params.recombination_iqtree_model : (params.iqtree_model ?: "MFP")

params.recombination_read_min_depth = params.containsKey('recombination_read_min_depth') ? params.recombination_read_min_depth : 30
params.recombination_read_min_major_af = params.containsKey('recombination_read_min_major_af') ? params.recombination_read_min_major_af : 0.90
params.mapping_outdir = params.containsKey('mapping_outdir') ? params.mapping_outdir : "${projectRoot}/outs/${params.analysis_name}/02.mapping_vs_pave/targeted_analysis"
params.variant_reports_dir = params.containsKey('variant_reports_dir') ? params.variant_reports_dir : "${projectRoot}/outs/${params.analysis_name}/03.variant_analysis/reports"
params.recombination_reference_fasta = params.containsKey('recombination_reference_fasta') ? params.recombination_reference_fasta : "${projectRoot}/refdata/pave/pave_hsa.fas"
params.recombination_hpv16_reference_chrom = params.containsKey('recombination_hpv16_reference_chrom') ? params.recombination_hpv16_reference_chrom : (params.lineage_ref_hpv16_name ?: "HPV16REF|lcl|Human")
params.recombination_hpv18_reference_chrom = params.containsKey('recombination_hpv18_reference_chrom') ? params.recombination_hpv18_reference_chrom : (params.lineage_ref_hpv18_name ?: "HPV18REF|lcl|Human")

params.recombination_enable_similarity_plot = params.containsKey('recombination_enable_similarity_plot') ? params.recombination_enable_similarity_plot : true

params.prepare_sequences_script = params.containsKey('prepare_sequences_script') ? params.prepare_sequences_script : "${params.scripts_dir}/recombination/prepare_recombination_inputs.py"
params.gard_runner_script = params.containsKey('gard_runner_script') ? params.gard_runner_script : "${params.scripts_dir}/recombination/run_hyphy_gard.sh"
params.gard_parser_script = params.containsKey('gard_parser_script') ? params.gard_parser_script : "${params.scripts_dir}/recombination/parse_gard_json.py"
params.summary_script = params.containsKey('summary_script') ? params.summary_script : "${params.scripts_dir}/recombination/summarize_recombination.py"
params.aggregate_script = params.containsKey('aggregate_script') ? params.aggregate_script : "${params.scripts_dir}/recombination/aggregate_recombination_reports.py"
params.plot_script = params.containsKey('plot_script') ? params.plot_script : "${params.scripts_dir}/recombination/plot_alignment_similarity.py"
params.openrdp_runner_script = params.containsKey('openrdp_runner_script') ? params.openrdp_runner_script : "${params.scripts_dir}/recombination/run_openrdp.py"
params.threeseq_runner_script = params.containsKey('threeseq_runner_script') ? params.threeseq_runner_script : "${params.scripts_dir}/recombination/run_3seq.py"
params.geneconv_runner_script = params.containsKey('geneconv_runner_script') ? params.geneconv_runner_script : "${params.scripts_dir}/recombination/run_geneconv.py"
params.tree_confirmation_script = params.containsKey('tree_confirmation_script') ? params.tree_confirmation_script : "${params.scripts_dir}/recombination/confirm_breakpoint_trees.py"
params.read_validation_script = params.containsKey('read_validation_script') ? params.read_validation_script : "${params.scripts_dir}/recombination/validate_recombination_reads.py"
params.screen_summary_script = params.containsKey('screen_summary_script') ? params.screen_summary_script : "${params.scripts_dir}/recombination/summarize_recombination_screen.py"
params.openrdp_summary_script = params.containsKey('openrdp_summary_script') ? params.openrdp_summary_script : "${params.scripts_dir}/recombination/summarize_recombination_openrdp.py"
params.threeseq_summary_script = params.containsKey('threeseq_summary_script') ? params.threeseq_summary_script : "${params.scripts_dir}/recombination/summarize_recombination_3seq.py"
params.geneconv_summary_script = params.containsKey('geneconv_summary_script') ? params.geneconv_summary_script : "${params.scripts_dir}/recombination/summarize_recombination_geneconv.py"

if (!params.outdir) error "params.outdir is required"
if (!params.reports_dir) error "params.reports_dir is required"
if (!(params.recombination_stage in ["screen", "openrdp", "3seq", "geneconv", "confirmation"])) {
    error "Unsupported recombination_stage='${params.recombination_stage}'. Choose one of: screen, openrdp, 3seq, geneconv, confirmation."
}
if (params.recombination_stage == "screen" && !params.recombination_sequences_tsv) {
    error "params.recombination_sequences_tsv is required for recombination_stage=screen"
}
if (params.recombination_stage == "openrdp" && !params.recombination_screen_groups_tsv) {
    error "params.recombination_screen_groups_tsv is required for recombination_stage=openrdp"
}
if (params.recombination_stage == "3seq" && !params.recombination_screen_groups_tsv) {
    error "params.recombination_screen_groups_tsv is required for recombination_stage=3seq"
}
if (params.recombination_stage == "geneconv" && !params.recombination_screen_groups_tsv) {
    error "params.recombination_screen_groups_tsv is required for recombination_stage=geneconv"
}
if (params.recombination_stage == "confirmation" && !params.recombination_openrdp_groups_tsv) {
    error "params.recombination_openrdp_groups_tsv is required for recombination_stage=confirmation"
}
if (params.recombination_stage == "screen" && params.recombination_input_mode != "metadata_fasta") {
    error "Unsupported recombination_input_mode='${params.recombination_input_mode}'. Only 'metadata_fasta' is currently supported."
}
if (params.recombination_stage in ["openrdp", "confirmation"] && !params.recombination_enable_openrdp) {
    error "recombination_enable_openrdp=false is not supported for recombination_stage=${params.recombination_stage}."
}

def checkPath(String path, String label) {
    def target = new File(path)
    if (!target.exists()) {
        error "${label} not found: ${path}"
    }
}

if (params.recombination_stage == "screen") {
    checkPath(params.recombination_sequences_tsv as String, 'Recombination sequence TSV')
    if (params.recombination_exclude_samples_tsv) {
        checkPath(params.recombination_exclude_samples_tsv as String, 'Recombination exclude samples list')
    }
    checkPath(params.prepare_sequences_script as String, 'Prepare sequences script')
    if (params.recombination_enable_gard) {
        checkPath(params.gard_runner_script as String, 'GARD runner script')
        checkPath(params.gard_parser_script as String, 'GARD parser script')
    }
    checkPath(params.plot_script as String, 'Recombination plot script')
    checkPath(params.screen_summary_script as String, 'Recombination screen summary script')
    checkPath(params.recombination_hpv16_background_fasta as String, 'HPV16 background FASTA')
    checkPath(params.recombination_hpv18_background_fasta as String, 'HPV18 background FASTA')
}
if (params.recombination_stage == "openrdp") {
    checkPath(params.recombination_screen_groups_tsv as String, 'Recombination screen groups TSV')
    checkPath(params.openrdp_runner_script as String, 'OpenRDP runner script')
    checkPath(params.openrdp_summary_script as String, 'Recombination OpenRDP summary script')
}
if (params.recombination_stage == "3seq") {
    checkPath(params.recombination_screen_groups_tsv as String, 'Recombination screen groups TSV')
    checkPath(params.threeseq_runner_script as String, '3SEQ runner script')
    checkPath(params.threeseq_summary_script as String, 'Recombination 3SEQ summary script')
}
if (params.recombination_stage == "geneconv") {
    checkPath(params.recombination_screen_groups_tsv as String, 'Recombination screen groups TSV')
    checkPath(params.geneconv_runner_script as String, 'GENECONV runner script')
    checkPath(params.geneconv_summary_script as String, 'Recombination GENECONV summary script')
}
if (params.recombination_stage == "confirmation") {
    checkPath(params.recombination_openrdp_groups_tsv as String, 'Recombination OpenRDP groups TSV')
    checkPath(params.summary_script as String, 'Recombination summary script')
    checkPath(params.aggregate_script as String, 'Recombination aggregate script')
    checkPath(params.tree_confirmation_script as String, 'Tree confirmation script')
    checkPath(params.read_validation_script as String, 'Read validation script')
    checkPath(params.variant_reports_dir as String, 'Variant reports directory')
    checkPath(params.mapping_outdir as String, 'Mapping output directory')
    checkPath(params.recombination_reference_fasta as String, 'Reference FASTA')
}

def multiqcConfigFile = file(params.multiqc_config)
if (!multiqcConfigFile.exists()) {
    error "MultiQC config not found: ${params.multiqc_config}"
}

process PREPARE_SEQUENCES {
    tag "prepare_sequences"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_*"
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "excluded_samples.tsv"

    input:
    path(sequence_table)

    output:
    path "recombination_groups.tsv", emit: groups_tsv
    path "recombination_input_manifest.tsv", emit: manifest
    path "recombination_duplicate_map.tsv", emit: duplicate_map
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
      --output-groups-tsv "recombination_groups.tsv" \\
      --output-manifest "recombination_input_manifest.tsv" \\
      --output-duplicate-map "recombination_duplicate_map.tsv" \\
      --output-excluded "excluded_samples.tsv" \\
      --output-summary-json "input_summary.json" \\
      --repo-root "${projectRoot}" \\
      --groups-root "${params.outdir}/summary/groups" \\
      --min-sequences "${params.recombination_min_sequences}" \\
      --background-mode "${params.recombination_background_mode}" \\
      --hpv16-background-fasta "${params.recombination_hpv16_background_fasta}" \\
      --hpv18-background-fasta "${params.recombination_hpv18_background_fasta}" \\
      ${optionalArgs}
    """
}

process ALIGN_MAFFT {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/alignment" }, mode: 'copy', pattern: "${group_id}.full.aln.fasta"

    input:
    tuple val(group_id), val(hpv_type), path(full_input), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    output:
    tuple val(group_id), val(hpv_type), path("${group_id}.full.aln.fasta"), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    script:
    """
    mafft ${params.recombination_mafft_args} "${full_input}" > "${group_id}.full.aln.fasta"
    """
}

process PASSTHROUGH_ALIGNMENT {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/alignment" }, mode: 'copy', pattern: "${group_id}.full.aln.fasta"

    input:
    tuple val(group_id), val(hpv_type), path(full_input), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    output:
    tuple val(group_id), val(hpv_type), path("${group_id}.full.aln.fasta"), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    script:
    """
    cp "${full_input}" "${group_id}.full.aln.fasta"
    """
}

process GARD_BREAKPOINTS {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.gard.json"
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.gard.breakpoints.tsv"
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.gard.summary.json"
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.gard.warnings.tsv"
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.gard.log"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path("${group_id}.gard.json"), path("${group_id}.gard.breakpoints.tsv"), path("${group_id}.gard.summary.json"), path("${group_id}.gard.warnings.tsv"), path("${group_id}.gard.log")

    script:
    """
    bash "${params.gard_runner_script}" \\
      "${alignment}" \\
      "${group_id}.gard.json" \\
      "${group_id}.gard.log" \\
      "${params.recombination_gard_model}" \\
      "${params.recombination_gard_rate_classes}" \\
      "${params.recombination_gard_max_breakpoints}"

    python3 "${params.gard_parser_script}" \\
      --input-json "${group_id}.gard.json" \\
      --output-breakpoints-tsv "${group_id}.gard.breakpoints.tsv" \\
      --output-summary-json "${group_id}.gard.summary.json" \\
      --output-warnings-tsv "${group_id}.gard.warnings.tsv" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}"
    """
}

process SKIP_GARD {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.gard.*"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path("${group_id}.gard.json"), path("${group_id}.gard.breakpoints.tsv"), path("${group_id}.gard.summary.json"), path("${group_id}.gard.warnings.tsv"), path("${group_id}.gard.log")

    script:
    """
    : > "${group_id}.gard.json"
    : > "${group_id}.gard.breakpoints.tsv"
    : > "${group_id}.gard.warnings.tsv"
    echo "GARD was not run (recombination_enable_gard=false)." > "${group_id}.gard.log"
    printf '{\\n  "analysis_group": "%s",\\n  "hpv_type": "%s",\\n  "status": "not_run",\\n  "n_breakpoints": 0\\n}\\n' \\
      "${group_id}" "${hpv_type}" > "${group_id}.gard.summary.json"
    """
}

process RUN_OPENRDP {
    tag { group_id }
    conda params.openrdp_conda_env
    publishDir { "${params.outdir}/openrdp" }, mode: 'copy', pattern: "${group_id}.openrdp.candidates.tsv"
    publishDir { "${params.outdir}/openrdp" }, mode: 'copy', pattern: "${group_id}.openrdp.summary.json"
    publishDir { "${params.outdir}/openrdp" }, mode: 'copy', pattern: "${group_id}.openrdp.log"
    publishDir { "${params.outdir}/openrdp" }, mode: 'copy', pattern: "${group_id}.openrdp.csv"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path("${group_id}.openrdp.candidates.tsv"), path("${group_id}.openrdp.summary.json"), path("${group_id}.openrdp.log"), path("${group_id}.openrdp.csv")

    script:
    def methodsArg = params.recombination_openrdp_methods
        .toString()
        .trim()
        .split(/\s+/)
        .findAll { it }
        .collect { "\"${it}\"" }
        .join(' ')
    """
    python3 "${params.openrdp_runner_script}" \\
      --alignment "${alignment}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --methods ${methodsArg} \\
      --pvalue-threshold "${params.recombination_openrdp_pvalue_threshold}" \\
      --min-segment-length "${params.recombination_openrdp_min_segment_length}" \\
      --combined-timeout-seconds "${params.recombination_openrdp_combined_timeout_seconds}" \\
      --method-timeout-seconds "${params.recombination_openrdp_method_timeout_seconds}" \\
      --sanitize-ambiguity-bases \\
      --output-candidates-tsv "${group_id}.openrdp.candidates.tsv" \\
      --output-summary-json "${group_id}.openrdp.summary.json" \\
      --output-log "${group_id}.openrdp.log" \\
      --output-csv "${group_id}.openrdp.csv"
    """
}

process RUN_3SEQ {
    tag { group_id }
    conda params.openrdp_conda_env
    publishDir { "${params.outdir}/3seq" }, mode: 'copy', pattern: "${group_id}.3seq.candidates.tsv"
    publishDir { "${params.outdir}/3seq" }, mode: 'copy', pattern: "${group_id}.3seq.summary.json"
    publishDir { "${params.outdir}/3seq" }, mode: 'copy', pattern: "${group_id}.3seq.log"
    publishDir { "${params.outdir}/3seq" }, mode: 'copy', pattern: "${group_id}.3seq.rec"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path("${group_id}.3seq.candidates.tsv"), path("${group_id}.3seq.summary.json"), path("${group_id}.3seq.log"), path("${group_id}.3seq.rec")

    script:
    """
    python3 "${params.threeseq_runner_script}" \\
      --alignment "${alignment}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --pvalue-threshold "${params.recombination_3seq_pvalue_threshold}" \\
      --min-segment-length "${params.recombination_3seq_min_segment_length}" \\
      --timeout-seconds "${params.recombination_3seq_timeout_seconds}" \\
      --sanitize-ambiguity-bases \\
      --output-candidates-tsv "${group_id}.3seq.candidates.tsv" \\
      --output-summary-json "${group_id}.3seq.summary.json" \\
      --output-log "${group_id}.3seq.log" \\
      --output-rec "${group_id}.3seq.rec"
    """
}

process RUN_GENECONV {
    tag { group_id }
    conda params.openrdp_conda_env
    publishDir { "${params.outdir}/geneconv" }, mode: 'copy', pattern: "${group_id}.geneconv.candidates.tsv"
    publishDir { "${params.outdir}/geneconv" }, mode: 'copy', pattern: "${group_id}.geneconv.summary.json"
    publishDir { "${params.outdir}/geneconv" }, mode: 'copy', pattern: "${group_id}.geneconv.log"
    publishDir { "${params.outdir}/geneconv" }, mode: 'copy', pattern: "${group_id}.geneconv.frags"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path("${group_id}.geneconv.candidates.tsv"), path("${group_id}.geneconv.summary.json"), path("${group_id}.geneconv.log"), path("${group_id}.geneconv.frags")

    script:
    """
    python3 "${params.geneconv_runner_script}" \\
      --alignment "${alignment}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --pvalue-threshold "${params.recombination_geneconv_pvalue_threshold}" \\
      --min-segment-length "${params.recombination_geneconv_min_segment_length}" \\
      --timeout-seconds "${params.recombination_geneconv_timeout_seconds}" \\
      --sanitize-ambiguity-bases \\
      --output-candidates-tsv "${group_id}.geneconv.candidates.tsv" \\
      --output-summary-json "${group_id}.geneconv.summary.json" \\
      --output-log "${group_id}.geneconv.log" \\
      --output-frags "${group_id}.geneconv.frags"
    """
}

process TREE_CONFIRMATION {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/trees" }, mode: 'copy', pattern: "${group_id}.tree_confirmation.tsv"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path(openrdp_candidates), path(openrdp_summary), path(openrdp_log), path(openrdp_csv)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path(openrdp_candidates), path(openrdp_summary), path(openrdp_log), path(openrdp_csv), path("${group_id}.tree_confirmation.tsv")

    script:
    """
    python3 "${params.tree_confirmation_script}" \\
      --alignment "${alignment}" \\
      --candidates-tsv "${openrdp_candidates}" \\
      --gard-summary-json "${gard_summary}" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --iqtree-bin "${params.recombination_iqtree_bin}" \\
      --model "${params.recombination_iqtree_model}" \\
      --bootstrap-replicates "${params.recombination_tree_bootstrap_replicates}" \\
      --bootstrap-threshold "${params.recombination_tree_min_bootstrap}" \\
      --output-tsv "${group_id}.tree_confirmation.tsv"
    """
}

process READ_VALIDATION {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/read_validation" }, mode: 'copy', pattern: "${group_id}.read_validation.tsv"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path(openrdp_candidates), path(openrdp_summary), path(openrdp_log), path(openrdp_csv), path(tree_confirmation)

    output:
    tuple val(group_id), val(hpv_type), path(manifest_tsv), path(duplicate_map_tsv), path(gard_json), path(gard_breakpoints), path(gard_summary), path(openrdp_candidates), path(openrdp_summary), path(tree_confirmation), path("${group_id}.read_validation.tsv")

    script:
    def chrom = hpv_type == 'HPV18' ? params.recombination_hpv18_reference_chrom : params.recombination_hpv16_reference_chrom
    """
    python3 "${params.read_validation_script}" \\
      --alignment "${alignment}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --candidates-tsv "${openrdp_candidates}" \\
      --gard-summary-json "${gard_summary}" \\
      --mapping-outdir "${params.mapping_outdir}" \\
      --reference-fasta "${params.recombination_reference_fasta}" \\
      --reference-chrom "${chrom}" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --min-depth "${params.recombination_read_min_depth}" \\
      --min-major-af "${params.recombination_read_min_major_af}" \\
      --output-tsv "${group_id}.read_validation.tsv"
    """
}

process GROUP_SUMMARY {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "${group_id}.recombination_*"

    input:
    tuple val(group_id), val(hpv_type), path(manifest_tsv), path(duplicate_map_tsv), path(gard_json), path(gard_breakpoints), path(gard_summary), path(openrdp_candidates), path(openrdp_summary), path(tree_confirmation), path(read_validation)

    output:
    path "${group_id}.recombination_events.tsv", emit: events_tsv
    path "${group_id}.recombination_events.csv", emit: events_csv
    path "${group_id}.recombination_events.json", emit: events_json
    path "${group_id}.recombination_summary.md", emit: summary_md
    path "${group_id}.recombination_warnings.tsv", emit: warnings_tsv
    path "${group_id}.recombination_type_overview.multiqc.tsv", emit: type_overview
    path "${group_id}.recombination_candidate_samples.multiqc.tsv", emit: candidate_samples
    path "${group_id}.recombination_breakpoint_support.multiqc.tsv", emit: breakpoint_support
    path "${group_id}.recombination_duplicate_map.tsv", emit: duplicate_map

    script:
    """
    python3 "${params.summary_script}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --duplicate-map-tsv "${duplicate_map_tsv}" \\
      --gard-json "${gard_json}" \\
      --gard-breakpoints-tsv "${gard_breakpoints}" \\
      --gard-summary-json "${gard_summary}" \\
      --openrdp-candidates-tsv "${openrdp_candidates}" \\
      --openrdp-summary-json "${openrdp_summary}" \\
      --tree-confirmation-tsv "${tree_confirmation}" \\
      --read-validation-tsv "${read_validation}" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --samples-vs-lineage-sets-tsv "${params.variant_reports_dir}/samples_vs_lineage_sets.tsv" \\
      --samples-vs-database-tsv "${params.variant_reports_dir}/samples_vs_database.tsv" \\
      --output-events-tsv "${group_id}.recombination_events.tsv" \\
      --output-events-csv "${group_id}.recombination_events.csv" \\
      --output-events-json "${group_id}.recombination_events.json" \\
      --output-summary-md "${group_id}.recombination_summary.md" \\
      --output-warnings-tsv "${group_id}.recombination_warnings.tsv" \\
      --output-type-overview-tsv "${group_id}.recombination_type_overview.multiqc.tsv" \\
      --output-candidate-samples-tsv "${group_id}.recombination_candidate_samples.multiqc.tsv" \\
      --output-breakpoint-support-tsv "${group_id}.recombination_breakpoint_support.multiqc.tsv" \\
      --output-duplicate-map-tsv "${group_id}.recombination_duplicate_map.tsv" \\
      --gard-support-confidence "${params.recombination_gard_confidence}"
    """
}

process SIMILARITY_PLOTS {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/plots" }, mode: 'copy', pattern: "${group_id}.pairwise_identity.tsv"
    publishDir { "${params.outdir}/plots" }, mode: 'copy', pattern: "${group_id}.pairwise_identity.png"
    publishDir { "${params.outdir}/plots" }, mode: 'copy', pattern: "${group_id}.plot.warnings.tsv"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    output:
    tuple val(group_id), val(hpv_type), path("${group_id}.pairwise_identity.tsv"), path("${group_id}.pairwise_identity.png"), path("${group_id}.plot.warnings.tsv")

    script:
    """
    python3 "${params.plot_script}" \\
      --alignment "${alignment}" \\
      --output-tsv "${group_id}.pairwise_identity.tsv" \\
      --output-png "${group_id}.pairwise_identity.png" \\
      --output-warnings "${group_id}.plot.warnings.tsv"
    """
}

process SCREEN_SUMMARY {
    tag "screen_summary"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_screen*"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "*.multiqc.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_screen_summary.md"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_screen_duplicate_map.tsv"

    input:
    path(groups_tsv)
    path(input_summary_json)
    path(duplicate_map_tsv)
    path(excluded_tsv)
    path(gard_breakpoints)
    path(gard_summaries)
    path(gard_warnings)

    output:
    path "recombination_screen_type_overview.multiqc.tsv", emit: type_overview
    path "recombination_screen_input_groups.multiqc.tsv", emit: input_groups
    path "recombination_screen_breakpoint_support.multiqc.tsv", emit: breakpoint_support
    path "recombination_screen_similarity_plots.multiqc.tsv", emit: similarity_plots
    path "recombination_screen_duplicate_map.tsv", emit: duplicate_map
    path "recombination_screen_summary.md", emit: summary_md
    path "recombination_screen_warnings.tsv", emit: warnings_tsv
    path "recombination_screen_groups.tsv", emit: groups_manifest

    script:
    def breakpointArgs = gard_breakpoints.collect { "\"${it}\"" }.join(' ')
    def summaryArgs = gard_summaries.collect { "\"${it}\"" }.join(' ')
    def warningArgs = gard_warnings.collect { "\"${it}\"" }.join(' ')
    def plotFlag = params.recombination_enable_similarity_plot ? "--similarity-plot-enabled" : ""
    def gardFlag = params.recombination_enable_gard ? "--gard-enabled" : ""
    """
    python3 "${params.screen_summary_script}" \\
      --groups-tsv "${groups_tsv}" \\
      --input-summary-json "${input_summary_json}" \\
      --duplicate-map-tsv "${duplicate_map_tsv}" \\
      --excluded-samples-tsv "${excluded_tsv}" \\
      --gard-breakpoints ${breakpointArgs} \\
      --gard-summaries ${summaryArgs} \\
      --gard-warnings ${warningArgs} \\
      --step-outdir "${params.outdir}" \\
      ${plotFlag} ${gardFlag} \\
      --output-type-overview-tsv "recombination_screen_type_overview.multiqc.tsv" \\
      --output-input-groups-tsv "recombination_screen_input_groups.multiqc.tsv" \\
      --output-breakpoint-support-tsv "recombination_screen_breakpoint_support.multiqc.tsv" \\
      --output-similarity-plots-tsv "recombination_screen_similarity_plots.multiqc.tsv" \\
      --output-duplicate-map-tsv "recombination_screen_duplicate_map.tsv" \\
      --output-summary-md "recombination_screen_summary.md" \\
      --output-warnings-tsv "recombination_screen_warnings.tsv" \\
      --output-groups-tsv "recombination_screen_groups.tsv"
    """
}

process OPENRDP_SUMMARY {
    tag "openrdp_summary"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_openrdp*"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "*.multiqc.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_openrdp_summary.md"

    input:
    path(screen_groups_tsv)
    path(openrdp_candidates)
    path(openrdp_summaries)
    path(openrdp_logs)
    path(openrdp_csvs)

    output:
    path "recombination_openrdp_type_overview.multiqc.tsv", emit: type_overview
    path "recombination_openrdp_candidate_samples.multiqc.tsv", emit: candidate_samples
    path "recombination_openrdp_method_failures.multiqc.tsv", emit: method_failures
    path "recombination_openrdp_summary.md", emit: summary_md
    path "recombination_openrdp_warnings.tsv", emit: warnings_tsv
    path "recombination_openrdp_groups.tsv", emit: groups_manifest

    script:
    def candidateArgs = openrdp_candidates.collect { "\"${it}\"" }.join(' ')
    def summaryArgs = openrdp_summaries.collect { "\"${it}\"" }.join(' ')
    def logArgs = openrdp_logs.collect { "\"${it}\"" }.join(' ')
    def csvArgs = openrdp_csvs.collect { "\"${it}\"" }.join(' ')
    """
    python3 "${params.openrdp_summary_script}" \\
      --screen-groups-tsv "${screen_groups_tsv}" \\
      --openrdp-candidates ${candidateArgs} \\
      --openrdp-summaries ${summaryArgs} \\
      --openrdp-logs ${logArgs} \\
      --openrdp-csvs ${csvArgs} \\
      --step-outdir "${params.outdir}" \\
      --output-type-overview-tsv "recombination_openrdp_type_overview.multiqc.tsv" \\
      --output-candidate-samples-tsv "recombination_openrdp_candidate_samples.multiqc.tsv" \\
      --output-method-failures-tsv "recombination_openrdp_method_failures.multiqc.tsv" \\
      --output-summary-md "recombination_openrdp_summary.md" \\
      --output-warnings-tsv "recombination_openrdp_warnings.tsv" \\
      --output-groups-tsv "recombination_openrdp_groups.tsv"
    """
}

process THREESEQ_SUMMARY {
    tag "3seq_summary"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_3seq*"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "*.multiqc.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_3seq_summary.md"

    input:
    path(screen_groups_tsv)
    path(candidates)
    path(summaries)
    path(logs)
    path(recs)

    output:
    path "recombination_3seq_type_overview.multiqc.tsv", emit: type_overview
    path "recombination_3seq_candidate_samples.multiqc.tsv", emit: candidate_samples
    path "recombination_3seq_method_failures.multiqc.tsv", emit: method_failures
    path "recombination_3seq_summary.md", emit: summary_md
    path "recombination_3seq_warnings.tsv", emit: warnings_tsv
    path "recombination_3seq_groups.tsv", emit: groups_manifest

    script:
    def candidateArgs = candidates.collect { "\"${it}\"" }.join(' ')
    def summaryArgs = summaries.collect { "\"${it}\"" }.join(' ')
    def logArgs = logs.collect { "\"${it}\"" }.join(' ')
    def recArgs = recs.collect { "\"${it}\"" }.join(' ')
    """
    python3 "${params.threeseq_summary_script}" \\
      --screen-groups-tsv "${screen_groups_tsv}" \\
      --candidates ${candidateArgs} \\
      --summaries ${summaryArgs} \\
      --logs ${logArgs} \\
      --recs ${recArgs} \\
      --step-outdir "${params.outdir}" \\
      --output-type-overview-tsv "recombination_3seq_type_overview.multiqc.tsv" \\
      --output-candidate-samples-tsv "recombination_3seq_candidate_samples.multiqc.tsv" \\
      --output-method-failures-tsv "recombination_3seq_method_failures.multiqc.tsv" \\
      --output-summary-md "recombination_3seq_summary.md" \\
      --output-warnings-tsv "recombination_3seq_warnings.tsv" \\
      --output-groups-tsv "recombination_3seq_groups.tsv"
    """
}

process GENECONV_SUMMARY {
    tag "geneconv_summary"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_geneconv*"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "*.multiqc.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_geneconv_summary.md"

    input:
    path(screen_groups_tsv)
    path(candidates)
    path(summaries)
    path(logs)
    path(frags)

    output:
    path "recombination_geneconv_type_overview.multiqc.tsv", emit: type_overview
    path "recombination_geneconv_candidate_samples.multiqc.tsv", emit: candidate_samples
    path "recombination_geneconv_method_failures.multiqc.tsv", emit: method_failures
    path "recombination_geneconv_summary.md", emit: summary_md
    path "recombination_geneconv_warnings.tsv", emit: warnings_tsv
    path "recombination_geneconv_groups.tsv", emit: groups_manifest

    script:
    def candidateArgs = candidates.collect { "\"${it}\"" }.join(' ')
    def summaryArgs = summaries.collect { "\"${it}\"" }.join(' ')
    def logArgs = logs.collect { "\"${it}\"" }.join(' ')
    def fragArgs = frags.collect { "\"${it}\"" }.join(' ')
    """
    python3 "${params.geneconv_summary_script}" \\
      --screen-groups-tsv "${screen_groups_tsv}" \\
      --candidates ${candidateArgs} \\
      --summaries ${summaryArgs} \\
      --logs ${logArgs} \\
      --frags ${fragArgs} \\
      --step-outdir "${params.outdir}" \\
      --output-type-overview-tsv "recombination_geneconv_type_overview.multiqc.tsv" \\
      --output-candidate-samples-tsv "recombination_geneconv_candidate_samples.multiqc.tsv" \\
      --output-method-failures-tsv "recombination_geneconv_method_failures.multiqc.tsv" \\
      --output-summary-md "recombination_geneconv_summary.md" \\
      --output-warnings-tsv "recombination_geneconv_warnings.tsv" \\
      --output-groups-tsv "recombination_geneconv_groups.tsv"
    """
}

process AGGREGATE_SUMMARY {
    tag "aggregate"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "recombination_*"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "*.multiqc.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_summary.md"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_duplicate_map.tsv"
    publishDir { "${params.reports_dir}" }, mode: 'copy', pattern: "recombination_events.tsv"

    input:
    path(type_overview_tables)
    path(candidate_tables)
    path(breakpoint_tables)
    path(duplicate_tables)
    path(summary_mds)
    path(event_tables)
    path(warning_tables)

    output:
    path "recombination_type_overview.multiqc.tsv", emit: type_overview
    path "recombination_candidate_samples.multiqc.tsv", emit: candidate_samples
    path "recombination_breakpoint_support.multiqc.tsv", emit: breakpoint_support
    path "recombination_duplicate_map.tsv", emit: duplicate_map
    path "recombination_summary.md", emit: summary_md
    path "recombination_events.tsv", emit: events_tsv
    path "recombination_events.csv", emit: events_csv
    path "recombination_events.json", emit: events_json
    path "recombination_warnings.tsv", emit: warnings_tsv

    script:
    def overviewArgs = type_overview_tables.collect { "\"${it}\"" }.join(' ')
    def candidateArgs = candidate_tables.collect { "\"${it}\"" }.join(' ')
    def breakpointArgs = breakpoint_tables.collect { "\"${it}\"" }.join(' ')
    def duplicateArgs = duplicate_tables.collect { "\"${it}\"" }.join(' ')
    def summaryArgs = summary_mds.collect { "\"${it}\"" }.join(' ')
    def eventArgs = event_tables.collect { "\"${it}\"" }.join(' ')
    def warningArgs = warning_tables.collect { "\"${it}\"" }.join(' ')
    """
    python3 "${params.aggregate_script}" \\
      --type-overview ${overviewArgs} \\
      --candidate-samples ${candidateArgs} \\
      --breakpoint-support ${breakpointArgs} \\
      --duplicate-map ${duplicateArgs} \\
      --summary-md ${summaryArgs} \\
      --events-tsv ${eventArgs} \\
      --warnings-tsv ${warningArgs} \\
      --output-type-overview "recombination_type_overview.multiqc.tsv" \\
      --output-candidate-samples "recombination_candidate_samples.multiqc.tsv" \\
      --output-breakpoint-support "recombination_breakpoint_support.multiqc.tsv" \\
      --output-duplicate-map "recombination_duplicate_map.tsv" \\
      --output-summary-md "recombination_summary.md" \\
      --output-events-tsv "recombination_events.tsv" \\
      --output-events-csv "recombination_events.csv" \\
      --output-events-json "recombination_events.json" \\
      --output-warnings-tsv "recombination_warnings.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.multiqc_env
    publishDir { "${params.multiqc_outdir}" }, mode: 'copy', pattern: "${params.multiqc_report_name}"

    input:
    path(multiqc_config)
    path(report_inputs)

    output:
    path("${params.multiqc_report_name}")

    script:
    """
    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      .
    """
}

workflow {
    if (params.recombination_stage == "screen") {
        def sequenceTable = file(params.recombination_sequences_tsv as String)
        if (!sequenceTable.exists()) {
            error "recombination_sequences_tsv not found: ${params.recombination_sequences_tsv}"
        }

        def prepared = PREPARE_SEQUENCES(Channel.of(sequenceTable))
        def groups = prepared.groups_tsv
            .splitCsv(header: true, sep: '\t')
            .map { row ->
                tuple(
                    row.analysis_group as String,
                    row.hpv_type as String,
                    file(row.full_input_fasta),
                    file(row.manifest_tsv),
                    file(row.duplicate_map_tsv),
                    file(row.representative_ids_tsv),
                    file(row.summary_json),
                    (row.sample_count as Integer),
                    (row.reference_count as Integer)
                )
            }

        def aligned = params.recombination_input_is_aligned ? PASSTHROUGH_ALIGNMENT(groups) : ALIGN_MAFFT(groups)
        if (params.recombination_enable_similarity_plot) {
            SIMILARITY_PLOTS(aligned)
        }
        def gard = params.recombination_enable_gard ? GARD_BREAKPOINTS(aligned) : SKIP_GARD(aligned)
        def screenSummary = SCREEN_SUMMARY(
            prepared.groups_tsv,
            prepared.summary_json,
            prepared.duplicate_map,
            prepared.excluded,
            gard.map { it[10] }.collect(),
            gard.map { it[11] }.collect(),
            gard.map { it[12] }.collect()
        )
        def screenReportInputs = screenSummary.type_overview
            .mix(screenSummary.input_groups)
            .mix(screenSummary.breakpoint_support)
            .mix(screenSummary.similarity_plots)
            .mix(screenSummary.duplicate_map)
            .mix(screenSummary.summary_md)
            .collect()
        MULTIQC(multiqcConfigFile, screenReportInputs)
    } else if (params.recombination_stage == "openrdp") {
        def screenGroupsPath = file(params.recombination_screen_groups_tsv as String)
        def screenGroups = Channel.of(screenGroupsPath)
            .splitCsv(header: true, sep: '\t')
            .map { row ->
                tuple(
                    row.analysis_group as String,
                    row.hpv_type as String,
                    file(row.alignment_fasta),
                    file(row.manifest_tsv),
                    file(row.duplicate_map_tsv),
                    file(row.representative_ids_tsv),
                    file(row.group_summary_json),
                    (row.sample_count as Integer),
                    (row.reference_count as Integer),
                    file(row.gard_json),
                    file(row.gard_breakpoints_tsv),
                    file(row.gard_summary_json),
                    file(row.gard_warnings_tsv),
                    file(row.gard_log)
                )
            }

        def openrdp = RUN_OPENRDP(screenGroups)
        def openrdpSummary = OPENRDP_SUMMARY(
            screenGroupsPath,
            openrdp.map { it[14] }.collect(),
            openrdp.map { it[15] }.collect(),
            openrdp.map { it[16] }.collect(),
            openrdp.map { it[17] }.collect()
        )
        def openrdpReportInputs = openrdpSummary.type_overview
            .mix(openrdpSummary.candidate_samples)
            .mix(openrdpSummary.method_failures)
            .mix(openrdpSummary.summary_md)
            .collect()
        MULTIQC(multiqcConfigFile, openrdpReportInputs)
    } else if (params.recombination_stage == "3seq") {
        def screenGroupsPath = file(params.recombination_screen_groups_tsv as String)
        def screenGroups = Channel.of(screenGroupsPath)
            .splitCsv(header: true, sep: '\t')
            .map { row ->
                tuple(
                    row.analysis_group as String,
                    row.hpv_type as String,
                    file(row.alignment_fasta),
                    file(row.manifest_tsv),
                    file(row.duplicate_map_tsv),
                    file(row.representative_ids_tsv),
                    file(row.group_summary_json),
                    (row.sample_count as Integer),
                    (row.reference_count as Integer),
                    file(row.gard_json),
                    file(row.gard_breakpoints_tsv),
                    file(row.gard_summary_json),
                    file(row.gard_warnings_tsv),
                    file(row.gard_log)
                )
            }

        def threeseq = RUN_3SEQ(screenGroups)
        def threeseqSummary = THREESEQ_SUMMARY(
            screenGroupsPath,
            threeseq.map { it[14] }.collect(),
            threeseq.map { it[15] }.collect(),
            threeseq.map { it[16] }.collect(),
            threeseq.map { it[17] }.collect()
        )
        def threeseqReportInputs = threeseqSummary.type_overview
            .mix(threeseqSummary.candidate_samples)
            .mix(threeseqSummary.method_failures)
            .mix(threeseqSummary.summary_md)
            .collect()
        MULTIQC(multiqcConfigFile, threeseqReportInputs)
    } else if (params.recombination_stage == "geneconv") {
        def screenGroupsPath = file(params.recombination_screen_groups_tsv as String)
        def screenGroups = Channel.of(screenGroupsPath)
            .splitCsv(header: true, sep: '\t')
            .map { row ->
                tuple(
                    row.analysis_group as String,
                    row.hpv_type as String,
                    file(row.alignment_fasta),
                    file(row.manifest_tsv),
                    file(row.duplicate_map_tsv),
                    file(row.representative_ids_tsv),
                    file(row.group_summary_json),
                    (row.sample_count as Integer),
                    (row.reference_count as Integer),
                    file(row.gard_json),
                    file(row.gard_breakpoints_tsv),
                    file(row.gard_summary_json),
                    file(row.gard_warnings_tsv),
                    file(row.gard_log)
                )
            }

        def geneconv = RUN_GENECONV(screenGroups)
        def geneconvSummary = GENECONV_SUMMARY(
            screenGroupsPath,
            geneconv.map { it[14] }.collect(),
            geneconv.map { it[15] }.collect(),
            geneconv.map { it[16] }.collect(),
            geneconv.map { it[17] }.collect()
        )
        def geneconvReportInputs = geneconvSummary.type_overview
            .mix(geneconvSummary.candidate_samples)
            .mix(geneconvSummary.method_failures)
            .mix(geneconvSummary.summary_md)
            .collect()
        MULTIQC(multiqcConfigFile, geneconvReportInputs)
    } else {
        def openrdpGroupsPath = file(params.recombination_openrdp_groups_tsv as String)
        def openrdpGroups = Channel.of(openrdpGroupsPath)
            .splitCsv(header: true, sep: '\t')
            .map { row ->
                tuple(
                    row.analysis_group as String,
                    row.hpv_type as String,
                    file(row.alignment_fasta),
                    file(row.manifest_tsv),
                    file(row.duplicate_map_tsv),
                    file(row.representative_ids_tsv),
                    file(row.group_summary_json),
                    (row.sample_count as Integer),
                    (row.reference_count as Integer),
                    file(row.gard_json),
                    file(row.gard_breakpoints_tsv),
                    file(row.gard_summary_json),
                    file(row.gard_warnings_tsv),
                    file(row.gard_log),
                    file(row.openrdp_candidates_tsv),
                    file(row.openrdp_summary_json),
                    file(row.openrdp_log),
                    file(row.openrdp_csv)
                )
            }

        def treeConfirmation = TREE_CONFIRMATION(openrdpGroups)
        def readValidation = READ_VALIDATION(treeConfirmation)
        def groupSummary = GROUP_SUMMARY(readValidation)
        def aggregate = AGGREGATE_SUMMARY(
            groupSummary.type_overview.collect(),
            groupSummary.candidate_samples.collect(),
            groupSummary.breakpoint_support.collect(),
            groupSummary.duplicate_map.collect(),
            groupSummary.summary_md.collect(),
            groupSummary.events_tsv.collect(),
            groupSummary.warnings_tsv.collect()
        )
        def finalReportInputs = aggregate.type_overview
            .mix(aggregate.candidate_samples)
            .mix(aggregate.breakpoint_support)
            .mix(aggregate.duplicate_map)
            .mix(aggregate.summary_md)
            .collect()
        MULTIQC(multiqcConfigFile, finalReportInputs)
    }
}

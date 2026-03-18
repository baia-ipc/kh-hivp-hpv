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
params.recombination_split_by_hpv_type = params.containsKey('recombination_split_by_hpv_type') ? params.recombination_split_by_hpv_type : true
params.recombination_background_mode = params.recombination_background_mode ?: "tree_selected_same_type"
params.recombination_hpv16_background_fasta = params.containsKey('recombination_hpv16_background_fasta') ? params.recombination_hpv16_background_fasta : "${projectRoot}/derived_data/refdata/hpv16_tree/selected_renamed.fasta"
params.recombination_hpv18_background_fasta = params.containsKey('recombination_hpv18_background_fasta') ? params.recombination_hpv18_background_fasta : "${projectRoot}/derived_data/refdata/hpv18_tree/selected_renamed.fasta"

params.recombination_gard_model = params.recombination_gard_model ?: "012345"
params.recombination_gard_rate_classes = params.containsKey('recombination_gard_rate_classes') ? params.recombination_gard_rate_classes : 3
params.recombination_gard_max_breakpoints = params.containsKey('recombination_gard_max_breakpoints') ? params.recombination_gard_max_breakpoints : 10
params.recombination_gard_confidence = params.recombination_gard_confidence ?: "low"

params.recombination_enable_3seq = params.containsKey('recombination_enable_3seq') ? params.recombination_enable_3seq : true
params.recombination_3seq_bin = params.containsKey('recombination_3seq_bin') ? params.recombination_3seq_bin : null
params.recombination_3seq_table = params.containsKey('recombination_3seq_table') ? params.recombination_3seq_table : null
params.recombination_3seq_cache_dir = params.containsKey('recombination_3seq_cache_dir') ? params.recombination_3seq_cache_dir : "${projectRoot}/derived_data/tools/3seq"
params.recombination_3seq_table_size = params.containsKey('recombination_3seq_table_size') ? params.recombination_3seq_table_size : 700
params.recombination_3seq_pvalue_threshold = params.containsKey('recombination_3seq_pvalue_threshold') ? params.recombination_3seq_pvalue_threshold : 0.01
params.recombination_3seq_min_segment_length = params.containsKey('recombination_3seq_min_segment_length') ? params.recombination_3seq_min_segment_length : 500

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
params.three_seq_bootstrap_script = params.containsKey('three_seq_bootstrap_script') ? params.three_seq_bootstrap_script : "${params.scripts_dir}/recombination/bootstrap_3seq.sh"
params.three_seq_runner_script = params.containsKey('three_seq_runner_script') ? params.three_seq_runner_script : "${params.scripts_dir}/recombination/run_3seq.py"
params.tree_confirmation_script = params.containsKey('tree_confirmation_script') ? params.tree_confirmation_script : "${params.scripts_dir}/recombination/confirm_breakpoint_trees.py"
params.read_validation_script = params.containsKey('read_validation_script') ? params.read_validation_script : "${params.scripts_dir}/recombination/validate_recombination_reads.py"

if (!params.outdir) error "params.outdir is required"
if (!params.reports_dir) error "params.reports_dir is required"
if (!params.recombination_sequences_tsv) error "params.recombination_sequences_tsv is required"
if (params.recombination_input_mode != "metadata_fasta") {
    error "Unsupported recombination_input_mode='${params.recombination_input_mode}'. Only 'metadata_fasta' is currently supported."
}

def checkPath(String path, String label) {
    def target = new File(path)
    if (!target.exists()) {
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
checkPath(params.aggregate_script as String, 'Recombination aggregate script')
checkPath(params.plot_script as String, 'Recombination plot script')
checkPath(params.recombination_hpv16_background_fasta as String, 'HPV16 background FASTA')
checkPath(params.recombination_hpv18_background_fasta as String, 'HPV18 background FASTA')
checkPath(params.variant_reports_dir as String, 'Variant reports directory')
checkPath(params.mapping_outdir as String, 'Mapping output directory')
checkPath(params.recombination_reference_fasta as String, 'Reference FASTA')

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
      --work-root "\$PWD" \\
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
    publishDir { "${params.outdir}/alignment" }, mode: 'copy', pattern: "${group_id}.*"

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
    publishDir { "${params.outdir}/alignment" }, mode: 'copy', pattern: "${group_id}.*"

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
    publishDir { "${params.outdir}/gard" }, mode: 'copy', pattern: "${group_id}.*"

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

process BOOTSTRAP_3SEQ {
    tag "3seq_bootstrap"
    conda params.conda_env
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "3seq_bootstrap.json"

    output:
    path "3seq_bootstrap.json", emit: summary
    path "3seq_bin.txt", emit: bin_txt
    path "3seq_table.txt", emit: table_txt

    script:
    def binArg = params.recombination_3seq_bin ? "\"${params.recombination_3seq_bin}\"" : "\"\""
    def tableArg = params.recombination_3seq_table ? "\"${params.recombination_3seq_table}\"" : "\"\""
    """
    bash "${params.three_seq_bootstrap_script}" \\
      "${params.recombination_3seq_cache_dir}" \\
      ${binArg} \\
      ${tableArg} \\
      "${params.recombination_3seq_table_size}" \\
      "3seq_bootstrap.json"

    python3 - <<'PY'
    import json
    payload = json.load(open("3seq_bootstrap.json", "r", encoding="utf-8"))
    open("3seq_bin.txt", "w", encoding="utf-8").write(payload["three_seq_bin"] + "\\n")
    open("3seq_table.txt", "w", encoding="utf-8").write(payload["three_seq_table"] + "\\n")
    PY
    """
}

process RUN_3SEQ {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/3seq" }, mode: 'copy', pattern: "${group_id}.*"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log)
    path(three_seq_bin_txt)
    path(three_seq_table_txt)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path("${group_id}.3seq.candidates.tsv"), path("${group_id}.3seq.summary.json"), path("${group_id}.3seq.log"), path("${group_id}.3seq.rec")

    script:
    """
    three_seq_bin=\$(cat "${three_seq_bin_txt}" | tr -d '\\n')
    three_seq_table=\$(cat "${three_seq_table_txt}" | tr -d '\\n')

    python3 "${params.three_seq_runner_script}" \\
      --alignment "${alignment}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --three-seq-bin "\$three_seq_bin" \\
      --three-seq-table "\$three_seq_table" \\
      --analysis-group "${group_id}" \\
      --hpv-type "${hpv_type}" \\
      --pvalue-threshold "${params.recombination_3seq_pvalue_threshold}" \\
      --min-segment-length "${params.recombination_3seq_min_segment_length}" \\
      --output-candidates-tsv "${group_id}.3seq.candidates.tsv" \\
      --output-summary-json "${group_id}.3seq.summary.json" \\
      --output-log "${group_id}.3seq.log" \\
      --output-rec "${group_id}.3seq.rec"
    """
}

process SKIP_3SEQ {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/3seq" }, mode: 'copy', pattern: "${group_id}.*"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path("${group_id}.3seq.candidates.tsv"), path("${group_id}.3seq.summary.json"), path("${group_id}.3seq.log"), path("${group_id}.3seq.rec")

    script:
    """
    printf 'analysis_group\\thpv_type\\tcandidate_id\\tparent_major_record_id\\tparent_minor_record_id\\tcandidate_record_id\\tcandidate_sample_id\\tcandidate_sequence_role\\tuncorrected_p\\tused_hogan_siegmund\\tlog10_p\\tcorrected_p\\tcorrected_p_mantissa\\tmin_segment_length\\tcandidate_breakpoint_site\\tcandidate_breakpoints\\tpasses_pvalue_threshold\\tpasses_segment_length\\teligible_sample_candidate\\n' > "${group_id}.3seq.candidates.tsv"
    python3 - <<'PY'
    import json
    payload = {
        "analysis_group": "${group_id}",
        "hpv_type": "${hpv_type}",
        "exit_code": 0,
        "candidate_triplets": 0,
        "sample_candidate_triplets": 0,
        "eligible_sample_candidates": 0,
    }
    with open("${group_id}.3seq.summary.json", "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\\n")
    PY
    : > "${group_id}.3seq.log"
    : > "${group_id}.3seq.rec"
    """
}

process TREE_CONFIRMATION {
    tag { group_id }
    conda params.conda_env
    publishDir { "${params.outdir}/trees" }, mode: 'copy', pattern: "${group_id}.*"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path(three_seq_candidates), path(three_seq_summary), path(three_seq_log), path(three_seq_rec)

    output:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path(three_seq_candidates), path(three_seq_summary), path(three_seq_log), path(three_seq_rec), path("${group_id}.tree_confirmation.tsv")

    script:
    """
    python3 "${params.tree_confirmation_script}" \\
      --alignment "${alignment}" \\
      --candidates-tsv "${three_seq_candidates}" \\
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
    publishDir { "${params.outdir}/read_validation" }, mode: 'copy', pattern: "${group_id}.*"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count), path(gard_json), path(gard_breakpoints), path(gard_summary), path(gard_warnings), path(gard_log), path(three_seq_candidates), path(three_seq_summary), path(three_seq_log), path(three_seq_rec), path(tree_confirmation)

    output:
    tuple val(group_id), val(hpv_type), path(manifest_tsv), path(duplicate_map_tsv), path(gard_json), path(gard_breakpoints), path(gard_summary), path(three_seq_candidates), path(three_seq_summary), path(tree_confirmation), path("${group_id}.read_validation.tsv")

    script:
    def chrom = hpv_type == 'HPV18' ? params.recombination_hpv18_reference_chrom : params.recombination_hpv16_reference_chrom
    """
    python3 "${params.read_validation_script}" \\
      --alignment "${alignment}" \\
      --manifest-tsv "${manifest_tsv}" \\
      --candidates-tsv "${three_seq_candidates}" \\
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
    publishDir { "${params.outdir}/summary" }, mode: 'copy', pattern: "${group_id}.*"

    input:
    tuple val(group_id), val(hpv_type), path(manifest_tsv), path(duplicate_map_tsv), path(gard_json), path(gard_breakpoints), path(gard_summary), path(three_seq_candidates), path(three_seq_summary), path(tree_confirmation), path(read_validation)

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
      --three-seq-candidates-tsv "${three_seq_candidates}" \\
      --three-seq-summary-json "${three_seq_summary}" \\
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
    publishDir { "${params.outdir}/plots" }, mode: 'copy', pattern: "${group_id}.*"

    input:
    tuple val(group_id), val(hpv_type), path(alignment), path(manifest_tsv), path(duplicate_map_tsv), path(representative_ids_tsv), path(group_summary_json), val(sample_count), val(reference_count)

    output:
    path "${group_id}.pairwise_identity.tsv", emit: pairwise_tsv
    path "${group_id}.pairwise_identity.png", emit: pairwise_png
    path "${group_id}.plot.warnings.tsv", emit: plot_warnings

    script:
    """
    python3 "${params.plot_script}" \\
      --alignment "${alignment}" \\
      --output-tsv "${group_id}.pairwise_identity.tsv" \\
      --output-png "${group_id}.pairwise_identity.png" \\
      --output-warnings "${group_id}.plot.warnings.tsv"
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
    path(type_overview)
    path(candidate_samples)
    path(breakpoint_support)
    path(duplicate_map)
    path(summary_md)

    output:
    path("${params.multiqc_report_name}")

    script:
    """
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

    def gard = GARD_BREAKPOINTS(aligned)
    def threeSeqAssets = params.recombination_enable_3seq ? BOOTSTRAP_3SEQ() : null
    def threeSeq = params.recombination_enable_3seq
        ? RUN_3SEQ(gard, threeSeqAssets.bin_txt, threeSeqAssets.table_txt)
        : SKIP_3SEQ(gard)
    def treeConfirmation = TREE_CONFIRMATION(threeSeq)
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

    MULTIQC(
        multiqcConfigFile,
        aggregate.type_overview,
        aggregate.candidate_samples,
        aggregate.breakpoint_support,
        aggregate.duplicate_map,
        aggregate.summary_md
    )
}

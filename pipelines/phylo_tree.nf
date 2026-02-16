#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = (params.containsKey('scripts_dir') && params.scripts_dir) ? params.scripts_dir : "${projectRoot}/scripts"
params.conda_env = (params.containsKey('conda_env') && params.conda_env) ? params.conda_env : "${projectRoot}/pipelines/conda_env/pipeline.env.yml"
params.multiqc_config = (params.containsKey('multiqc_config') && params.multiqc_config) ? params.multiqc_config : "${projectRoot}/pipelines/multiqc/phylo_tree.multiqc.yml"
params.analysis_name = params.containsKey('analysis_name') ? params.analysis_name : null
params.step_name = (params.containsKey('step_name') && params.step_name) ? params.step_name : "04.phylo_tree"
params.input_step_name = (params.containsKey('input_step_name') && params.input_step_name) ? params.input_step_name : "02.mapping_vs_pave"
def outdirParam = params.containsKey('outdir') ? params.outdir : null
def reportsDirParam = params.containsKey('reports_dir') ? params.reports_dir : null
def multiqcOutdirParam = params.containsKey('multiqc_outdir') ? params.multiqc_outdir : null
def multiqcReportNameParam = params.containsKey('multiqc_report_name') ? params.multiqc_report_name : null
def mappingOutdirParam = params.containsKey('mapping_outdir') ? params.mapping_outdir : null

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
if (!mappingOutdirParam && params.analysis_name && params.input_step_name) {
    mappingOutdirParam = "${projectRoot}/outs/${params.analysis_name}/${params.input_step_name}"
}

params.multiqc_outdir = multiqcOutdirParam
params.multiqc_report_name = multiqcReportNameParam
params.mapping_outdir = mappingOutdirParam
params.refdata_dir = params.containsKey('refdata_dir') ? params.refdata_dir : null
params.derived_dir = params.containsKey('derived_dir') ? params.derived_dir : null
params.input_dir = params.containsKey('input_dir') ? params.input_dir : params.derived_dir
params.lineages_tsv = params.containsKey('lineages_tsv') ? params.lineages_tsv : null
params.lineage_refs_tsv = params.containsKey('lineage_refs_tsv') ? params.lineage_refs_tsv : null
params.ncbi_tsv = params.containsKey('ncbi_tsv') ? params.ncbi_tsv : null
params.ncbi_fasta = params.containsKey('ncbi_fasta') ? params.ncbi_fasta : null
params.outgroups_fasta = params.containsKey('outgroups_fasta') ? params.outgroups_fasta : null
params.selected_tsv = params.containsKey('selected_tsv') ? params.selected_tsv : null
params.acc_country_tsv = params.containsKey('acc_country_tsv') ? params.acc_country_tsv : null
params.acc_country_cols = params.containsKey('acc_country_cols') ? params.acc_country_cols : null
params.outgroups_list = params.containsKey('outgroups_list') ? params.outgroups_list : null
params.selection_list = params.containsKey('selection_list') ? params.selection_list : null
params.selection_columns = params.containsKey('selection_columns') ? params.selection_columns : null
params.samples_tsv = params.containsKey('samples_tsv') ? params.samples_tsv : null
params.strains_tsv = params.containsKey('strains_tsv') ? params.strains_tsv : null
params.bcf_dir = params.containsKey('bcf_dir') ? params.bcf_dir : null
params.bcf_run_id = params.containsKey('bcf_run_id') ? params.bcf_run_id : null
params.sample_prep_script = params.containsKey('sample_prep_script') ? params.sample_prep_script : null
params.lineage_extract_script = params.containsKey('lineage_extract_script') ? params.lineage_extract_script : null
params.lineage_refs_build_script = (params.containsKey('lineage_refs_build_script') && params.lineage_refs_build_script) ? params.lineage_refs_build_script : "${params.scripts_dir}/phylo_tree/build_lineage_refs_tsv.py"
params.lineage_refs_lineage_col = params.containsKey('lineage_refs_lineage_col') ? params.lineage_refs_lineage_col : 4
params.lineage_refs_accession_col = params.containsKey('lineage_refs_accession_col') ? params.lineage_refs_accession_col : 6
params.selection_script = params.containsKey('selection_script') ? params.selection_script : null
params.rename_tsv = params.containsKey('rename_tsv') ? params.rename_tsv : null
params.rename_acc_col = params.containsKey('rename_acc_col') ? params.rename_acc_col : null
params.rename_prefix_col = params.containsKey('rename_prefix_col') ? params.rename_prefix_col : null
params.skip_id = params.containsKey('skip_id') ? params.skip_id : null
params.hpv_type = params.containsKey('hpv_type') ? params.hpv_type : null
params.ref_name = params.containsKey('ref_name') ? params.ref_name : null
params.ref_pattern = params.containsKey('ref_pattern') ? params.ref_pattern : null
params.strains_match = params.containsKey('strains_match') ? params.strains_match : null
params.tree_render_script = (params.containsKey('tree_render_script') && params.tree_render_script) ? params.tree_render_script : "${params.scripts_dir}/phylo_tree/render_tree_svg.py"
params.tree_stats_script = (params.containsKey('tree_stats_script') && params.tree_stats_script) ? params.tree_stats_script : "${params.scripts_dir}/phylo_tree/compute_tree_stats.py"
params.selection_build_script = (params.containsKey('selection_build_script') && params.selection_build_script) ? params.selection_build_script : "${params.scripts_dir}/phylo_tree/build_tree_selection_tsv.py"
params.tree_layout = (params.containsKey('tree_layout') && params.tree_layout) ? params.tree_layout : "circular"
params.tree_use_branch_lengths = (params.containsKey('tree_use_branch_lengths') && params.tree_use_branch_lengths) ? params.tree_use_branch_lengths : false

def inputDirParam = params.input_dir
def outdirRuntimeParam = params.containsKey('outdir') ? params.outdir : null
def reportsDirRuntimeParam = params.containsKey('reports_dir') ? params.reports_dir : null
def outgroupsFileParam = params.containsKey('outgroups_file') ? params.outgroups_file : null
def iqtreeOutgroupsParam = params.containsKey('iqtree_outgroups') ? params.iqtree_outgroups : null

if (!inputDirParam) {
    error "params.input_dir is required"
}
if (!outdirRuntimeParam && params.analysis_name && params.step_name) {
    outdirRuntimeParam = "${projectRoot}/outs/${params.analysis_name}/${params.step_name}"
}
if (!outdirRuntimeParam) {
    error "params.outdir is required"
}
if (!reportsDirRuntimeParam) {
    reportsDirRuntimeParam = "${outdirRuntimeParam}/reports"
}

params.outdir = outdirRuntimeParam
params.reports_dir = reportsDirRuntimeParam

if (!outgroupsFileParam && params.outgroups_list) {
    outgroupsFileParam = params.outgroups_list
}
params.outgroups_file = outgroupsFileParam

def inputDir = new File(params.input_dir as String)
if (!inputDir.isDirectory()) {
    inputDir.mkdirs()
}

def refdataDir = params.refdata_dir ? new File(params.refdata_dir as String) : null
def derivedDir = params.derived_dir ? new File(params.derived_dir as String) : inputDir
if (refdataDir && !refdataDir.isDirectory()) {
    error "refdata_dir not found: ${params.refdata_dir}"
}
if (!derivedDir.isDirectory()) {
    derivedDir.mkdirs()
}
params.derived_dir = derivedDir.toString()
if (!params.lineage_refs_tsv && params.hpv_type) {
    params.lineage_refs_tsv = "${params.derived_dir}/${params.hpv_type.toString().toLowerCase()}_lineage_refs.tsv"
}

def checkPath(String path, String label) {
    def target = new File(path)
    if (!target.exists()) {
        error "${label} not found: ${path}"
    }
}

def checkDir(String path, String label) {
    def target = new File(path)
    if (!target.isDirectory()) {
        error "${label} directory not found: ${path}"
    }
}

if (!params.lineages_tsv) error "params.lineages_tsv is required"
if (!params.ncbi_tsv) error "params.ncbi_tsv is required"
if (!params.ncbi_fasta) error "params.ncbi_fasta is required"
if (!params.selected_tsv) error "params.selected_tsv is required"
if (!params.selection_list) error "params.selection_list is required"
if (!params.selection_columns) error "params.selection_columns is required"
if (!params.outgroups_list) error "params.outgroups_list is required"
if (!params.samples_tsv) error "params.samples_tsv is required"
if (!params.mapping_outdir) error "params.mapping_outdir is required"
if (!params.sample_prep_script) error "params.sample_prep_script is required"
if (!params.lineage_extract_script) error "params.lineage_extract_script is required"
if (!params.lineage_refs_tsv) error "params.lineage_refs_tsv is required"
if (!params.selection_script) error "params.selection_script is required"
if (!params.hpv_type) error "params.hpv_type is required"

checkPath(params.lineages_tsv as String, 'Lineages TSV')
checkPath(params.ncbi_tsv as String, 'NCBI TSV')
checkPath(params.ncbi_fasta as String, 'NCBI FASTA')
checkPath(params.selection_list as String, 'Selection list')
checkPath(params.outgroups_list as String, 'Outgroups list')
if (!params.outgroups_fasta) {
    params.outgroups_fasta = params.ncbi_fasta
}
checkPath(params.outgroups_fasta as String, 'Outgroups FASTA')
checkPath(params.samples_tsv as String, 'Samples TSV')
checkDir(params.mapping_outdir as String, 'Mapping output')
checkPath(params.sample_prep_script as String, 'Sample prep script')
checkPath(params.lineage_extract_script as String, 'Lineage extract script')
checkPath(params.lineage_refs_build_script as String, 'Lineage refs build script')
checkPath(params.selection_script as String, 'Selection script')
checkPath(params.tree_render_script as String, 'Tree render script')
checkPath(params.tree_stats_script as String, 'Tree stats script')
checkPath(params.selection_build_script as String, 'Selection build script')

if (!iqtreeOutgroupsParam && outgroupsFileParam) {
    def outgroupsFile = new File(params.outgroups_file as String)
    if (!outgroupsFile.exists()) {
        error "outgroups_file not found: ${params.outgroups_file}"
    }
    def outgroups = outgroupsFile.readLines()
        .collect { it.trim() }
        .findAll { it && !it.startsWith('#') }
    if (!outgroups.isEmpty()) {
        iqtreeOutgroupsParam = outgroups.join(',')
    }
}
params.iqtree_outgroups = iqtreeOutgroupsParam

def mafftArgs = params.mafft_args ?: ""

def trimalGt = params.trimal_gt ?: 0.90

def trimalSt = params.trimal_st ?: 0.01

def iqtreeModel = params.iqtree_model ?: "MFP"

def iqtreeThreads = params.iqtree_threads ?: "AUTO"

def iqtreeBootstrap = params.iqtree_bootstrap ?: 1000

def iqtreeAlrt = params.iqtree_alrt ?: 1000

def multiqc_config_file = file(params.multiqc_config)
if (!multiqc_config_file.exists()) {
    error "MultiQC config not found: ${params.multiqc_config}"
}

process PREP_LINEAGES {
    tag "prepare_lineages"
    publishDir { "${params.derived_dir}" }, mode: 'copy'
    conda params.conda_env

    input:
    path(lineages_tsv)
    path(ncbi_fasta)

    output:
    path "lineages_ref.fasta", emit: ref
    path "lineages_ref_renamed.fasta", emit: renamed

    script:
    """
    "${params.lineage_extract_script}" \\
      "${lineages_tsv}" \\
      "${ncbi_fasta}" \\
      lineages_ref.fasta

    python3 "${params.scripts_dir}/phylo_tree/rename_lineages.py" \\
      "${lineages_tsv}" 6 4 \\
      lineages_ref.fasta \\
      lineages_ref_renamed.fasta
    """
}

process PREP_LINEAGE_REFS {
    tag "prepare_lineage_refs"
    publishDir { "${params.derived_dir}" }, mode: 'copy'
    conda params.conda_env
    def refsOut = new File(params.lineage_refs_tsv.toString()).getName()

    input:
    path(lineages_tsv)

    output:
    path "${refsOut}", emit: refs

    script:
    """
    python3 "${params.lineage_refs_build_script}" \\
      --lineages-tsv "${lineages_tsv}" \\
      --lineage-col "${params.lineage_refs_lineage_col}" \\
      --accession-col "${params.lineage_refs_accession_col}" \\
      --output "${refsOut}"
    """
}

process PREP_SELECTED {
    tag "prepare_selected"
    publishDir { "${params.derived_dir}" }, mode: 'copy'
    conda params.conda_env
    def accCountryOut = params.acc_country_tsv ? new File(params.acc_country_tsv.toString()).getName() : "acc_country.tsv"

    input:
    path(ncbi_tsv)
    path(ncbi_fasta)
    path(selected_tsv)

    output:
    path "selected.fasta", emit: selected
    path "selected_renamed.fasta", emit: renamed
    path accCountryOut, emit: acc_country, optional: true

    script:
    def envLines = []
    if (params.acc_country_tsv) { envLines << "ACC_COUNTRY_TSV=\"${accCountryOut}\"" }
    if (params.acc_country_cols) { envLines << "ACC_COUNTRY_COLS=\"${params.acc_country_cols}\"" }
    if (params.selection_columns) { envLines << "SELECTION_COLS=\"${params.selection_columns}\"" }
    if (params.rename_tsv) { envLines << "RENAME_TSV=\"${params.rename_tsv}\"" }
    if (params.rename_acc_col) { envLines << "RENAME_ACC_COL=\"${params.rename_acc_col}\"" }
    if (params.rename_prefix_col) { envLines << "RENAME_PREFIX_COL=\"${params.rename_prefix_col}\"" }
    if (params.skip_id) { envLines << "SKIP_ID=\"${params.skip_id}\"" }
    def envBlock = envLines ? envLines.join(" \\\n    ") + " \\\n" : ""
    """
    ${envBlock}"${params.selection_script}" \\
      "${ncbi_tsv}" \\
      "${ncbi_fasta}" \\
      "${selected_tsv}" \\
      selected.fasta \\
      selected_renamed.fasta
    """
}

process PREP_SELECTION_TSV {
    tag "prepare_selection_tsv"
    publishDir { "${params.derived_dir}" }, mode: 'copy'
    conda params.conda_env
    def selectedName = new File(params.selected_tsv.toString()).getName()

    input:
    path(ncbi_tsv)
    path(selection_list)
    val(selection_columns)

    output:
    path "${selectedName}"

    script:
    """
    python3 "${params.selection_build_script}" \\
      --ncbi-tsv "${ncbi_tsv}" \\
      --selection-list "${selection_list}" \\
      --columns "${selection_columns}" \\
      --output "${selectedName}"
    """
}

process PREP_OUTGROUPS {
    tag "prepare_outgroups"
    publishDir { "${params.derived_dir}" }, mode: 'copy'
    conda params.conda_env

    input:
    path(outgroups_list)
    path(outgroups_fasta)

    output:
    path "outgroups.fasta"

    script:
    """
    seqkit grep -f "${outgroups_list}" -r "${outgroups_fasta}" > outgroups.fasta
    """
}

process PREP_SAMPLES {
    tag "prepare_samples"
    publishDir { "${params.derived_dir}" }, mode: 'copy'
    conda params.conda_env

    input:
    val(dummy)

    output:
    path "samples.fasta"

    script:
    """
    HPV_TYPE="${params.hpv_type}" \\
    REF_NAME="${params.ref_name ?: ''}" \\
    REF_PATTERN="${params.ref_pattern ?: ''}" \\
    STRAINS_MATCH="${params.strains_match ?: ''}" \\
    OUT_DIR="${params.derived_dir}" \\
    MAPPING_OUTDIR="${params.mapping_outdir}" \\
    BCF_DIR="${params.bcf_dir ?: ''}" \\
    BCF_RUN_ID="${params.bcf_run_id ?: ''}" \\
    SAMPLES_TSV="${params.samples_tsv}" \\
    STRAINS_TSV="${params.strains_tsv ?: ''}" \\
    "${params.sample_prep_script}"
    cp "${params.derived_dir}/samples.fasta" samples.fasta
    """
}

process CAT_ALL {
    tag "cat_all"
    publishDir { "${params.outdir}" }, mode: 'copy'

    input:
    path selected
    path outgroups
    path lineages
    path samples

    output:
    path "all.fasta"

    script:
    """
    cat \
      "${selected}" \
      "${outgroups}" \
      "${lineages}" \
      "${samples}" \
      > all.fasta
    """
}

process MAFFT_ALIGN {
    tag "mafft"
    publishDir { "${params.outdir}" }, mode: 'copy'

    input:
    path all_fasta

    output:
    path "all_mafft_aligned.fasta"

    script:
    """
    mafft ${mafftArgs} --thread ${task.cpus} "${all_fasta}" > all_mafft_aligned.fasta
    """
}

process TRIMAL {
    tag "trimal"
    publishDir { "${params.outdir}" }, mode: 'copy'

    input:
    path aligned

    output:
    path "all_mafft_aligned.UPPER.fasta", emit: upper
    path "all_trimal.fasta", emit: trimal

    script:
    """
    awk 'BEGIN{FS=""} /^>/{gsub(":", "_");} {print}' "${aligned}" | sed 's/[a-z]/\\U&/g' > all_mafft_aligned.UPPER.fasta
    trimal -in all_mafft_aligned.UPPER.fasta -out all_trimal.fasta -gt ${trimalGt} -st ${trimalSt}
    """
}

process IQTREE {
    tag "iqtree"
    publishDir { "${params.outdir}" }, mode: 'copy'

    input:
    path trimal_fasta

    output:
    path "all_trimal.fasta.treefile", emit: treefile
    path "all_trimal.fasta.iqtree", emit: iqtree
    path "all_trimal.fasta.*", emit: all_files

    script:
    def outgroupsArg = params.iqtree_outgroups ? "-o ${params.iqtree_outgroups}" : ""
    """
    iqtree -s "${trimal_fasta}" ${outgroupsArg} -m ${iqtreeModel} -nt ${iqtreeThreads} -bb ${iqtreeBootstrap} -alrt ${iqtreeAlrt}
    """
}

process RENDER_TREE {
    tag "render_tree"
    publishDir { "${params.outdir}" }, mode: 'copy'
    conda params.conda_env

    input:
    path treefile

    output:
    path "phylo_tree.svg", emit: svg
    path "phylo_tree.png", emit: png

    script:
    def branchLengthsArg = params.tree_use_branch_lengths ? "--use-branch-lengths \\\n      " : ""
    """
    python3 "${params.tree_render_script}" \\
      --treefile "${treefile}" \\
      --layout "${params.tree_layout}" \\
      ${branchLengthsArg}--svg phylo_tree.svg \\
      --png phylo_tree.png
    """
}

process TREE_STATS {
    tag "tree_stats"
    publishDir { "${params.reports_dir}" }, mode: 'copy'
    conda params.conda_env

    input:
    path selected
    path outgroups
    path lineages
    path samples
    path aligned
    path trimmed
    path iqtree_file
    path treefile

    output:
    path "phylo_tree_summary.multiqc.tsv"

    script:
    """
    python3 "${params.tree_stats_script}" \\
      --selected "${selected}" \\
      --outgroups "${outgroups}" \\
      --lineages "${lineages}" \\
      --samples "${samples}" \\
      --aligned "${aligned}" \\
      --trimmed "${trimmed}" \\
      --iqtree "${iqtree_file}" \\
      --treefile "${treefile}" \\
      --output phylo_tree_summary.multiqc.tsv
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
    mkdir -p "${params.reports_dir}"
    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      "${params.outdir}" "${params.reports_dir}"

    python3 - "${params.multiqc_report_name}" "${params.outdir}/phylo_tree.svg" <<'PY'
import base64
from pathlib import Path
import sys

report_path = Path(sys.argv[1])
svg_path = Path(sys.argv[2])

if report_path.exists() and svg_path.exists():
    html = report_path.read_text(encoding="utf-8")
    svg_b64 = base64.b64encode(svg_path.read_bytes()).decode("ascii")
    html = html.replace('src="phylo_tree.svg"', f'src="data:image/svg+xml;base64,{svg_b64}"', 1)
    report_path.write_text(html, encoding="utf-8")
PY
    """
}

workflow {
    def lineagesTsv = file(params.lineages_tsv)
    def ncbiTsv = file(params.ncbi_tsv)
    def ncbiFasta = file(params.ncbi_fasta)
    def outgroupsList = file(params.outgroups_list)

    def lineagesReady = PREP_LINEAGES(lineagesTsv, ncbiFasta).renamed
    def lineageRefsReady = PREP_LINEAGE_REFS(lineagesTsv).refs

    def selectedTsvReady = PREP_SELECTION_TSV(
        ncbiTsv,
        file(params.selection_list as String),
        params.selection_columns
    )

    def selectedReady = PREP_SELECTED(ncbiTsv, ncbiFasta, selectedTsvReady).renamed

    def outgroupsFasta = file(params.outgroups_fasta as String)
    def outgroupsReady = PREP_OUTGROUPS(outgroupsList, outgroupsFasta)

    def samplesReady = PREP_SAMPLES(Channel.value(true))

    def cat_all = CAT_ALL(selectedReady, outgroupsReady, lineagesReady, samplesReady)
    def aligned = MAFFT_ALIGN(cat_all)
    def trimmed = TRIMAL(aligned)
    def tree = IQTREE(trimmed.trimal)
    def tree_rendered = RENDER_TREE(tree.treefile)
    def stats = TREE_STATS(selectedReady, outgroupsReady, lineagesReady, samplesReady, aligned, trimmed.trimal, tree.iqtree, tree.treefile)
    def qc_inputs = tree_rendered.svg.mix(stats).mix(lineageRefsReady)
    MULTIQC(multiqc_config_file, qc_inputs.collect())
}

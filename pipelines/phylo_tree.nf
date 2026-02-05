#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

def inputDirParam = params.containsKey('input_dir') ? params.input_dir : null
def outdirParam = params.containsKey('outdir') ? params.outdir : null
def reportsDirParam = params.containsKey('reports_dir') ? params.reports_dir : null
def outgroupsFileParam = params.containsKey('outgroups_file') ? params.outgroups_file : null
def iqtreeOutgroupsParam = params.containsKey('iqtree_outgroups') ? params.iqtree_outgroups : null

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/pipelines/conda_env/pipeline.env.yml"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/phylo_tree.multiqc.yml"
params.multiqc_outdir = params.multiqc_outdir ?: params.reports_dir
params.multiqc_report_name = params.multiqc_report_name ?: "multiqc_report.html"
params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: null
params.input_step_name = params.input_step_name ?: null
if (!params.outdir && params.analysis_name && params.step_name) {
    params.outdir = "${projectRoot}/outs/${params.analysis_name}/${params.step_name}"
}
if (!params.reports_dir && params.outdir) {
    params.reports_dir = "${params.outdir}/reports"
}
if (!params.multiqc_report_name && params.step_name) {
    params.multiqc_report_name = params.step_name.replace('.', '_') + ".report.html"
}
if ((!params.multiqc_outdir || params.multiqc_outdir.contains('unknown_analysis')) && params.analysis_name) {
    params.multiqc_outdir = "${projectRoot}/results/reports/${params.analysis_name}"
}
if (!params.mapping_outdir && params.analysis_name && params.input_step_name) {
    params.mapping_outdir = "${projectRoot}/outs/${params.analysis_name}/${params.input_step_name}"
}
params.refdata_dir = params.refdata_dir ?: null
params.derived_dir = params.derived_dir ?: null
params.input_dir = params.input_dir ?: params.derived_dir
params.lineages_tsv = params.lineages_tsv ?: null
params.ncbi_tsv = params.ncbi_tsv ?: null
params.ncbi_fasta = params.ncbi_fasta ?: null
params.selected_tsv = params.selected_tsv ?: null
params.acc_country_tsv = params.acc_country_tsv ?: null
params.acc_country_cols = params.acc_country_cols ?: null
params.outgroups_list = params.outgroups_list ?: null
params.selection_list = params.selection_list ?: null
params.selection_columns = params.selection_columns ?: null
params.samples_tsv = params.samples_tsv ?: null
params.mapping_outdir = params.mapping_outdir ?: null
params.strains_tsv = params.strains_tsv ?: null
params.sample_prep_script = params.sample_prep_script ?: null
params.lineage_extract_script = params.lineage_extract_script ?: null
params.selection_script = params.selection_script ?: null
params.rename_tsv = params.rename_tsv ?: null
params.rename_acc_col = params.rename_acc_col ?: null
params.rename_prefix_col = params.rename_prefix_col ?: null
params.hpv_type = params.hpv_type ?: null
params.ref_name = params.ref_name ?: null
params.ref_pattern = params.ref_pattern ?: null
params.strains_match = params.strains_match ?: null
params.tree_render_script = params.tree_render_script ?: "${params.scripts_dir}/phylo_tree/render_tree_svg.py"
params.tree_stats_script = params.tree_stats_script ?: "${params.scripts_dir}/phylo_tree/compute_tree_stats.py"
params.selection_build_script = params.selection_build_script ?: "${params.scripts_dir}/phylo_tree/build_tree_selection_tsv.py"

if (!inputDirParam) {
    error "params.input_dir is required"
}
if (!outdirParam) {
    error "params.outdir is required"
}
if (!reportsDirParam) {
    reportsDirParam = "${outdirParam}/reports"
}

params.input_dir = inputDirParam
params.outdir = outdirParam
params.reports_dir = reportsDirParam
params.outgroups_file = outgroupsFileParam
params.iqtree_outgroups = iqtreeOutgroupsParam

if (!params.outgroups_file && params.outgroups_list) {
    params.outgroups_file = params.outgroups_list
}

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

def needsUpdate(File output, List<File> inputs) {
    if (!output.exists()) return true
    def outMtime = output.lastModified()
    for (def inp : inputs) {
        if (inp.exists() && inp.lastModified() > outMtime) {
            return true
        }
    }
    return false
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
if (!params.selection_script) error "params.selection_script is required"
if (!params.hpv_type) error "params.hpv_type is required"

checkPath(params.lineages_tsv as String, 'Lineages TSV')
checkPath(params.ncbi_tsv as String, 'NCBI TSV')
checkPath(params.ncbi_fasta as String, 'NCBI FASTA')
checkPath(params.selection_list as String, 'Selection list')
checkPath(params.outgroups_list as String, 'Outgroups list')
checkPath(params.samples_tsv as String, 'Samples TSV')
checkDir(params.mapping_outdir as String, 'Mapping output')
checkPath(params.sample_prep_script as String, 'Sample prep script')
checkPath(params.lineage_extract_script as String, 'Lineage extract script')
checkPath(params.selection_script as String, 'Selection script')
checkPath(params.tree_render_script as String, 'Tree render script')
checkPath(params.tree_stats_script as String, 'Tree stats script')
checkPath(params.selection_build_script as String, 'Selection build script')

if (!params.iqtree_outgroups && params.outgroups_file) {
    def outgroupsFile = new File(params.outgroups_file as String)
    if (!outgroupsFile.exists()) {
        error "outgroups_file not found: ${params.outgroups_file}"
    }
    def outgroups = outgroupsFile.readLines()
        .collect { it.trim() }
        .findAll { it && !it.startsWith('#') }
    if (!outgroups.isEmpty()) {
        params.iqtree_outgroups = outgroups.join(',')
    }
}

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
    publishDir "${params.derived_dir}", mode: 'copy'
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

process PREP_SELECTED {
    tag "prepare_selected"
    publishDir "${params.derived_dir}", mode: 'copy'
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
    def envBlock = envLines ? envLines.join(" \\\\\n    ") + " \\\\\n" : ""
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
    publishDir "${params.derived_dir}", mode: 'copy'
    conda params.conda_env
    def selectedName = new File(params.selected_tsv.toString()).getName()

    input:
    path(ncbi_tsv)
    path(selection_list)
    val(selection_columns)

    output:
    path(selectedName)

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
    publishDir "${params.derived_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(outgroups_list)
    path(ncbi_fasta)

    output:
    path "outgroups.fasta"

    script:
    """
    seqkit grep -f "${outgroups_list}" -r "${ncbi_fasta}" > outgroups.fasta
    """
}

process PREP_SAMPLES {
    tag "prepare_samples"
    publishDir "${params.derived_dir}", mode: 'copy'
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
    SAMPLES_TSV="${params.samples_tsv}" \\
    STRAINS_TSV="${params.strains_tsv ?: ''}" \\
    "${params.sample_prep_script}"
    cp "${params.derived_dir}/samples.fasta" samples.fasta
    """
}

process CAT_ALL {
    tag "cat_all"
    publishDir "${params.outdir}", mode: 'copy'

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
    publishDir "${params.outdir}", mode: 'copy'

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
    publishDir "${params.outdir}", mode: 'copy'

    input:
    path aligned

    output:
    path "all_mafft_aligned.UPPER.fasta", emit: upper
    path "all_trimal.fasta", emit: trimal

    script:
    """
    sed 's/[a-z]/\\U&/g' "${aligned}" > all_mafft_aligned.UPPER.fasta
    trimal -in all_mafft_aligned.UPPER.fasta -out all_trimal.fasta -gt ${trimalGt} -st ${trimalSt}
    """
}

process IQTREE {
    tag "iqtree"
    publishDir "${params.outdir}", mode: 'copy'

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
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path treefile

    output:
    path "phylo_tree.svg", emit: svg
    path "phylo_tree.png", emit: png

    script:
    """
    python3 "${params.tree_render_script}" \\
      --treefile "${treefile}" \\
      --svg phylo_tree.svg \\
      --png phylo_tree.png
    """
}

process TREE_STATS {
    tag "tree_stats"
    publishDir "${params.reports_dir}", mode: 'copy'
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
    publishDir "${params.multiqc_outdir}", mode: 'copy'

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
    """
}

workflow {
    def lineagesTsv = file(params.lineages_tsv)
    def ncbiTsv = file(params.ncbi_tsv)
    def ncbiFasta = file(params.ncbi_fasta)
    def selectedTsv = file(params.selected_tsv)
    def outgroupsList = file(params.outgroups_list)
    def samplesTsv = file(params.samples_tsv)

    def lineagesRenamedPath = new File(derivedDir, 'lineages_ref_renamed.fasta')
    def selectedRenamedPath = new File(derivedDir, 'selected_renamed.fasta')
    def outgroupsPath = new File(derivedDir, 'outgroups.fasta')
    def samplesPath = new File(derivedDir, 'samples.fasta')
    def selectedTsvPath = file(params.selected_tsv)

    def lineagesReady
    if (needsUpdate(lineagesRenamedPath, [lineagesTsv, ncbiFasta])) {
        lineagesReady = PREP_LINEAGES(lineagesTsv, ncbiFasta).renamed
    } else {
        lineagesReady = Channel.value(file(lineagesRenamedPath.toString()))
    }

    def selectionInputs = [file(params.selection_list as String), ncbiTsv]
    def selectedTsvReady
    if (needsUpdate(selectedTsvPath, selectionInputs)) {
        selectedTsvReady = PREP_SELECTION_TSV(ncbiTsv, file(params.selection_list as String), params.selection_columns)
    } else {
        selectedTsvReady = Channel.value(selectedTsvPath)
    }

    def selectedReady
    if (needsUpdate(selectedRenamedPath, [selectedTsvPath, ncbiTsv, ncbiFasta])) {
        selectedReady = PREP_SELECTED(ncbiTsv, ncbiFasta, selectedTsvReady).renamed
    } else {
        selectedReady = Channel.value(file(selectedRenamedPath.toString()))
    }

    def outgroupsReady
    if (needsUpdate(outgroupsPath, [outgroupsList, ncbiFasta])) {
        outgroupsReady = PREP_OUTGROUPS(outgroupsList, ncbiFasta)
    } else {
        outgroupsReady = Channel.value(file(outgroupsPath.toString()))
    }

    def sampleInputs = [samplesTsv, new File(params.mapping_outdir as String)]
    if (params.strains_tsv) {
        sampleInputs << new File(params.strains_tsv as String)
    }
    def samplesReady
    if (needsUpdate(samplesPath, sampleInputs)) {
        samplesReady = PREP_SAMPLES(Channel.value(true))
    } else {
        samplesReady = Channel.value(file(samplesPath.toString()))
    }

    def cat_all = CAT_ALL(selectedReady, outgroupsReady, lineagesReady, samplesReady)
    def aligned = MAFFT_ALIGN(cat_all)
    def trimmed = TRIMAL(aligned)
    def tree = IQTREE(trimmed.trimal)
    def tree_rendered = RENDER_TREE(tree.treefile)
    def stats = TREE_STATS(selectedReady, outgroupsReady, lineagesReady, samplesReady, aligned, trimmed.trimal, tree.iqtree, tree.treefile)
    def qc_inputs = tree_rendered.svg.mix(stats)
    MULTIQC(multiqc_config_file, qc_inputs.collect())
}

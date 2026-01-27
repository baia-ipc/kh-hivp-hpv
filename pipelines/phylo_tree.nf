#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = Paths.get(workflow.projectDir).resolve('..').normalize().toString()

params.input_dir = params.input_dir ?: null
params.outdir = params.outdir ?: null
params.outgroups_file = params.outgroups_file ?: null

if (!params.input_dir) {
    error "params.input_dir is required"
}
if (!params.outdir) {
    error "params.outdir is required"
}

def requiredInputs = [
    'selected_renamed.fasta',
    'outgroups.fasta',
    'lineages_ref_renamed.fasta',
    'samples.fasta'
]

def inputDir = new File(params.input_dir as String)
if (!inputDir.isDirectory()) {
    error "input_dir not found: ${params.input_dir}"
}

requiredInputs.each { name ->
    def path = new File(inputDir, name)
    if (!path.exists()) {
        error "missing input file: ${path}"
    }
}

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
    path "all_trimal.fasta.*"

    script:
    def outgroupsArg = params.iqtree_outgroups ? "-o ${params.iqtree_outgroups}" : ""
    """
    iqtree -s "${trimal_fasta}" ${outgroupsArg} -m ${iqtreeModel} -nt ${iqtreeThreads} -bb ${iqtreeBootstrap} -alrt ${iqtreeAlrt}
    """
}

workflow {
    def selected = file("${params.input_dir}/selected_renamed.fasta")
    def outgroups = file("${params.input_dir}/outgroups.fasta")
    def lineages = file("${params.input_dir}/lineages_ref_renamed.fasta")
    def samples = file("${params.input_dir}/samples.fasta")

    def cat_all = CAT_ALL(selected, outgroups, lineages, samples)
    def aligned = MAFFT_ALIGN(cat_all)
    def trimmed = TRIMAL(aligned)
    IQTREE(trimmed.trimal)
}

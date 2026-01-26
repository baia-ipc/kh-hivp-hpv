The current analysis is partially reproducible, but not completely well organized.
This is due to the fact that analysis and scripts were done over 3 years.
The goal is to clean-up, restructure, re-order the scripts and analysis files
so that the entire pipeline can be reproduced more easily.

This includes also writing as script some manual commands called and documented
e.g. only in README.md files.

Also: in some cases, the output directory of a step contains further scripts,
but this is not the right location from them.

Also: The scripts should usually all be located in the general scripts directory,
and customizations for steps be passed to them as parameters etc. It is acceptable
that single steps scripts are containing calls to the main scripts, but in general
they should contain the less code possible, while most of the code must be in the
main scripts (repository "scripts" directory) and pipelines (repository "pipelines"
directory).

If manual steps must be run (e.g. selecting files for the phylogenetic trees)
these should be, whenever possible, be run before the automatic pipeline. E.g. the
selected strains to be included in the trees can be assumed to be downloaded by the
user and put into a conventional location (e.g. "refdata").

Indices which can be re-used (e.g. pave) must be located into a general directory
under the repository root.

In the final product, there shall be only analysis-input1 and analysis-input2.

----

The final repository will contain Nextflow pipelines:
- a pipeline for the entire analysis-input1
- a pipeline for the entire analysis-input2, except the phylogenetic trees
- a pipeline for the phylogenetic trees

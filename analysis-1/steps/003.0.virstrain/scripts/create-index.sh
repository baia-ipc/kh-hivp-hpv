#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
INDEXDIR=$STEPDIR/index
REFGENOMESFAS=/srv/giorgio/refdata/pave/human/20231102/pave_hsa.fas

mkdir -p $INDEXDIR
cd $INDEXDIR
ln -f -s $REFGENOMESFAS .

function create_msa {
  mafft --auto pave_hsa.fas > pave_hsa.msa.fas
}

function fix_msa {
  $SCRIPTSDIR/fix_msa_formatting.py pave_hsa.msa.fas > \
    pave_hsa.msa.virstrain.fas
}

function create_index {
  virstrain_build -i pave_hsa.msa.virstrain.fas -d virstrain
}

create_msa
fix_msa
create_index

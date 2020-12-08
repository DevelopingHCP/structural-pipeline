#!/bin/bash

# local directories
export parameters_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# setup path from installation
[ ! -f $parameters_dir/path.sh ] || . $parameters_dir/path.sh

# Draw-EM initial configuration
. $DRAWEMDIR/parameters/configuration.sh

export AVAILABLE_TEMPLATES="neonatal fetal"

# MNI T1, mask and warps
export MNI_T1=$DRAWEMDIR/atlases/MNI/MNI152_T1_1mm.nii.gz
export MNI_MASK=$DRAWEMDIR/atlases/MNI/MNI152_T1_1mm_facemask.nii.gz
export MNI_DOFS=$DRAWEMDIR/atlases/non-rigid-v2/dofs-MNI

# registration parameters
export REGISTRATION_CONFIG=$parameters_dir/ireg-structural.cfg
export REGISTRATION_TEMPLATE_CONFIG=$parameters_dir/ireg.cfg

# surface reconstuction parameters
export SURFACE_RECON_CONFIG=$parameters_dir/recon-neonatal-cortex.cfg
export SURFACE_RECON_FROM_SEG_CONFIG=$parameters_dir/recon-neonatal-cortex-from-seg.cfg

# log function
run()
{
  echo "$@"
  "$@"
  if [ ! $? -eq 0 ]; then
    echo "$@ : failed"
    exit 1
  fi
}

# make run function global
typeset -fx run
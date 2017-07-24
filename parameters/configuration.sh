#!/bin/bash

# local directories
export parameters_dir=$(dirname "$BASH_SOURCE")
export code_dir=$parameters_dir/..

# setup path from installation
[ ! -f $parameters_dir/path.sh ] || . $parameters_dir/path.sh

# cortical structures of labels file
export cortical_structures=`cat $DRAWEMDIR/parameters/cortical.csv`

# lookup table used with the wb_command to load labels
export LUT=$DRAWEMDIR/parameters/segAllLut.txt

# tissue labels of tissue-labels file
export CSF_label=1
export CGM_label=2
export WM_label=3
export BG_label=4

# MNI T1, mask and warps
export MNI_T1=$code_dir/atlases/MNI/MNI152_T1_1mm.nii.gz
export MNI_mask=$code_dir/atlases/MNI/MNI152_T1_1mm_facemask.nii.gz
export MNI_dofs=$code_dir/atlases/non-rigid-v2/dofs-MNI

# Average space atlas name, T2 and warps
export template_name="non-rigid-v2"
export template_T2=$code_dir/atlases/non-rigid-v2/T2
export template_dofs=$code_dir/atlases/non-rigid-v2/dofs
export template_min_age=28
export template_max_age=44

# registration parameters
export registration_config=$parameters_dir/ireg-structural.cfg
export registration_config_template=$parameters_dir/ireg.cfg

# surface reconstuction parameters
export surface_recon_config=$parameters_dir/recon-neonatal-cortex.cfg

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
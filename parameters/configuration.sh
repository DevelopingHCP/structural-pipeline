#!/bin/bash

if [ -n "$DRAWEMDIR" ]; then
  [ -d "$DRAWEMDIR" ] || { echo "DRAWEMDIR environment variable invalid!" 1>&2; exit 1; }
else
  echo "DRAWEMDIR environment variable not set!" 1>&2; exit 1;
fi

if [ -n "$SPHERICALMESHDIR" ]; then
  [ -d "$SPHERICALMESHDIR" ] || { echo "SPHERICALMESHDIR environment variable invalid!" 1>&2; exit 1; }
else
  echo "SPHERICALMESHDIR environment variable not set!" 1>&2; exit 1;
fi

export parameters_dir=$(dirname "$BASH_SOURCE")
export code_dir=$parameters_dir/..

# cortical structures of labels file
export cortical_structures=`cat $DRAWEMDIR/parameters/cortical.csv`

# tissue labels of tissue-labels file
export CSF_label=1
export CGM_label=2
export WM_label=3
export BG_label=4
# lookup table used with the wb_command to load labels
export LUT=$DRAWEMDIR/parameters/segAllLut.txt

export N4=$DRAWEMDIR/ThirdParty/ITK/N4
export MNI_T1=$code_dir/atlases/MNI/MNI152_T1_1mm.nii.gz
export MNI_mask=$code_dir/atlases/MNI/MNI152_T1_1mm_facemask.nii.gz
export MNI_dofs=$code_dir/atlases/non-rigid-v2/dofs-MNI

export template_name="non-rigid-v2"
export template_T2=$code_dir/atlases/atlases/non-rigid-v2/T2
export template_dofs=$code_dir/atlases/atlases/non-rigid-v2/dofs

export registration_config=$parameters_dir/ireg-structural.cfg
export registration_config_template=$parameters_dir/ireg.cfg

export surface_recon_config=$parameters_dir/recon-neonatal-cortex.cfg
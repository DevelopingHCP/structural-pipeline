#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject scan_age [options]
This script creates additional files for the dHCP structural pipeline.

Arguments:
  subject                       Subject ID

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -h / -help / --help           Print usage.
"
  exit;
}


process_image(){
  m=$1
  run fslmaths restore/$m/$subj.nii.gz -thr 0 restore/$m/$subj.nii.gz
  if [ ! -f restore/$m/${subj}_restore.nii.gz ];then
    run N4 3 -i restore/$m/$subj.nii.gz -x masks/$subj-bet.nii.gz -o "[restore/$m/${subj}_restore.nii.gz,restore/$m/${subj}_bias.nii.gz]" -c "[50x50x50,0.001]" -s 2 -b "[100,3]" -t "[0.15,0.01,200]"
  fi
  run fslmaths restore/$m/${subj}_restore.nii.gz -mul masks/$subj.nii.gz restore/$m/${subj}_restore_brain.nii.gz
  run fslmaths restore/$m/${subj}_restore.nii.gz -mul masks/$subj-bet.nii.gz restore/$m/${subj}_restore_bet.nii.gz
}

deface_image(){
  m=$1
  run fslmaths restore/$m/$subj.nii.gz -mul masks/${subj}_mask_defaced.nii.gz restore/$m/${subj}_defaced.nii.gz
  run fslmaths restore/$m/${subj}_restore.nii.gz -mul masks/${subj}_mask_defaced.nii.gz restore/$m/${subj}_restore_defaced.nii.gz
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
subj=$1
age=$2

datadir=`pwd`
threads=1
scriptdir=$(dirname "$BASH_SOURCE")

shift; shift
while [ $# -gt 0 ]; do
  case "$1" in
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;; 
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done


echo "additional files for the dHCP pipeline
Subject:    $subj 
Directory:  $datadir 
Threads:    $threads

$BASH_SOURCE $command
----------------------------"

################ MAIN ################
cd $datadir

mkdir -p restore/T2

T1masked=restore/T1/${subj}_restore_bet.nii.gz
T2masked=restore/T2/${subj}_restore_bet.nii.gz

# process T2 (bias correct, masked versions)
if [ ! -f $T2masked ];then 
  cp T2/$subj.nii.gz restore/T2/$subj.nii.gz
  process_image T2
fi

# register T1 -> T2 and warp
# process T1 (bias correct, masked versions)
if [ -f T1/$subj.nii.gz -a ! -f $T1masked ];then 
  mkdir -p restore/T1

  if [ ! -f dofs/$subj-T2-T1-r.dof.gz ];then 
    run mirtk padding $T2masked segmentations/${subj}_tissue_labels.nii.gz restore/T1/$subj-T2-brain.nii.gz 3 $CSF_label $CGM_label $BG_label 0
    run mirtk register restore/T1/$subj-T2-brain.nii.gz T1/$subj.nii.gz -model Rigid -dofout dofs/$subj-T2-T1-r.dof.gz -threads $threads
    rm restore/T1/$subj-T2-brain.nii.gz
  fi
  run mirtk transform-image T1/$subj.nii.gz restore/T1/$subj.nii.gz -target T2/$subj.nii.gz -dofin dofs/$subj-T2-T1-r.dof.gz -bspline

  process_image T1
fi

# register MNI -> T1 and transform a MNI mask
if [ ! -f masks/${subj}_mask_defaced.nii.gz ];then 
  if [ ! -f dofs/$subj-MNI-n.dof.gz ];then 
    run mirtk compose-dofs dofs/$subj-template-$age-n.dof.gz $MNI_dofs/template-$age-MNI-n.dof.gz dofs/$subj-MNI-init-n.dof.gz 
    run mirtk register $T2masked $MNI_T1 -dofin dofs/$subj-MNI-init-n.dof.gz -dofout dofs/$subj-MNI-n.dof.gz -parin $registration_config -threads $threads > /dev/null
    rm dofs/$subj-MNI-init-n.dof.gz 
  fi
  run mirtk transform-image $MNI_mask masks/${subj}_MNI_mask.nii.gz -dofin dofs/$subj-MNI-n.dof.gz -target $T2masked
  run fslmaths masks/${subj}_MNI_mask.nii.gz -add masks/$subj.nii.gz -bin masks/${subj}_mask_defaced.nii.gz
  rm masks/${subj}_MNI_mask.nii.gz
fi

# deface images
for m in T1 T2;do
  if [ ! -f restore/$m/${subj}_restore_defaced.nii.gz ];then
    deface_image $m
  fi
done


if [ ! -f dofs/template-$age-$subj-n.dof.gz ];then
  run mirtk register $T2masked $template_T2/template-$age.nii.gz -dofout dofs/template-$age-$subj-n.dof.gz -parin $registration_config_template -threads $threads > /dev/null
fi

if [ ! -f dofs/$subj-template-$age-r.dof.gz ];then
  run mirtk convert-dof dofs/$subj-template-$age-n.dof.gz dofs/$subj-template-$age-r.dof.gz -input-format mirtk -output-format rigid
fi

if [ ! -f dofs/template-$age-$subj-n.dof.gz ];then
  run mirtk invert-dof dofs/$subj-template-$age-n.dof.gz dofs/template-$age-$subj-i.dof.gz
  run mirtk register $template_T2/template-$age.nii.gz $T2masked -dofin dofs/template-$age-$subj-i.dof.gz -dofout dofs/template-$age-$subj-n.dof.gz -parin $registration_config_template -threads $threads > /dev/null
  run rm dofs/template-$age-$subj-i.dof.gz 
fi

if [ $age != 40 ];then 
  if [ ! -f dofs/$subj-template-40-n.dof.gz ];then
    run mirtk convert-dof dofs/$subj-template-$age-n.dof.gz dofs/$subj-template-$age-a.dof.gz -output-format affine
    run mirtk compose-dofs dofs/$subj-template-$age-a.dof.gz $template_dofs/$age-40-a.dof.gz  dofs/$subj-template-40-i.dof.gz -target $T2masked
    run mirtk register $T2masked $template_T2/template-40.nii.gz -dofin dofs/$subj-template-40-i.dof.gz -dofout dofs/$subj-template-40-n.dof.gz -parin $registration_config_template -threads threads > /dev/null
    run rm dofs/$subj-template-$age-a.dof.gz dofs/$subj-template-$age-i.dof.gz
  fi
  if [ ! -f dofs/template-40-$subj-n.dof.gz ];then
    run mirtk convert-dof dofs/template-$age-$subj-n.dof.gz dofs/template-$age-$subj-a.dof.gz -output-format affine
    run mirtk compose-dofs $template_dofs/40-$age-a.dof.gz dofs/template-$age-$subj-a.dof.gz dofs/template-40-$subj-i.dof.gz -target $template_T2/template-40.nii.gz
    run mirtk register $template_T2/template-40.nii.gz $T2masked -dofin dofs/template-40-$subj-i.dof.gz -dofout dofs/template-40-$subj-n.dof.gz -parin $registration_config_template -threads threads > /dev/null
    run rm dofs/template-$age-$subj-a.dof.gz dofs/template-$age-$subj-i.dof.gz
  fi
fi
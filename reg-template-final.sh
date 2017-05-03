#!/bin/bash

run(){
  echo "$@"
  "$@" 
}
subj=$1
age=$2

datadir=`pwd`
threads=1
scriptdir=~/vol/Setup/dhcp-structural-pipeline-latest/dhcp-structural-pipeline/scripts/v2.4/misc

age=`printf "%.*f\n" 0 $age` #round
[ $age -lt 44 ] || { age=44; }
[ $age -gt 28 ] || { age=28; }

mni=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz
mnimask=$scriptdir/../../../atlases/MNI/MNI152_T1_1mm_facemask.nii.gz
mnidofs=$scriptdir/../../../atlases/non-rigid-v2/dofs-MNI
templatedofs=$scriptdir/../../../atlases/non-rigid-v2/dofs

if [ ! -f dofs/template-$age-$subj-n.dof.gz ];then
    run mirtk invert-dof dofs/$subj-template-$age-n.dof.gz dofs/template-$age-$subj-i.dof.gz
    run mirtk register $DRAWEMDIR/atlases/non-rigid-v2/T2/template-$age.nii.gz N4/$subj.nii.gz -dofin dofs/template-$age-$subj-i.dof.gz -dofout dofs/template-$age-$subj-n.dof.gz -parin $DRAWEMDIR/parameters/ireg.cfg -threads 1 > /dev/null
    run rm dofs/template-$age-$subj-i.dof.gz 
fi

if [ $age != 40 ];then 
  if [ ! -f dofs/$subj-template-40-n.dof.gz ];then
      run mirtk convert-dof dofs/$subj-template-$age-n.dof.gz dofs/$subj-template-$age-a.dof.gz -output-format affine
      run mirtk compose-dofs dofs/$subj-template-$age-a.dof.gz $templatedofs/$age-40-a.dof.gz  dofs/$subj-template-40-i.dof.gz -target N4/$subj.nii.gz
      run mirtk register N4/$subj.nii.gz $DRAWEMDIR/atlases/non-rigid-v2/T2/template-40.nii.gz -dofin dofs/$subj-template-40-i.dof.gz -dofout dofs/$subj-template-40-n.dof.gz -parin $DRAWEMDIR/parameters/ireg.cfg -threads 1 > /dev/null
      run rm dofs/$subj-template-$age-a.dof.gz dofs/$subj-template-$age-i.dof.gz
  fi
  if [ ! -f dofs/template-40-$subj-n.dof.gz ];then
      run mirtk convert-dof dofs/template-$age-$subj-n.dof.gz dofs/template-$age-$subj-a.dof.gz -output-format affine
      run mirtk compose-dofs $templatedofs/40-$age-a.dof.gz dofs/template-$age-$subj-a.dof.gz dofs/template-40-$subj-i.dof.gz -target $DRAWEMDIR/atlases/non-rigid-v2/T2/template-40.nii.gz
      run mirtk register $DRAWEMDIR/atlases/non-rigid-v2/T2/template-40.nii.gz N4/$subj.nii.gz -dofin dofs/template-40-$subj-i.dof.gz -dofout dofs/template-40-$subj-n.dof.gz -parin $DRAWEMDIR/parameters/ireg.cfg -threads 1 > /dev/null
      run rm dofs/template-$age-$subj-a.dof.gz dofs/template-$age-$subj-i.dof.gz
  fi
fi


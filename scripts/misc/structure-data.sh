#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base entries.csv results_dir release_dir
This script uploads all the results.

Arguments:
  entries.csv            Entries for the subjects (subjectID-sessionID) used for the release
  release_dir             The directory used for the release. 
  data_dir                The directory used to output the files. 
"
  exit;
}

[ $# -ge 5 ] || { usage; }

subjectID=$1
sessionID=$2
subj=$3
age=$4

releasedir=$5
datadir=`pwd`
if [ $# -ge 6 ];then 
    datadir=$6; 
    cd $datadir
    datadir=`pwd`
fi
minimal=1
if [ $# -ge 7 ];then 
  minimal=$7
fi


action=cp
Hemi=('left' 'right');
Cortex=('CORTEX_LEFT' 'CORTEX_RIGHT');

subjdir=sub-$subjectID
sessiondir=ses-$sessionID
prefix=${subjdir}_${sessiondir}
anat=$subjdir/$sessiondir/anat
outputRawDir=$releasedir/sourcedata/$anat
outputDerivedDir=$releasedir/derivatives/$anat
outputSurfDir=$outputDerivedDir/Native
outputWarpDir=$outputDerivedDir/xfms

mkdir -p $outputSurfDir $outputWarpDir $outputRawDir
# images
ms=T2
if [ -f T1/$subj.nii.gz ];then ms="T1 T2"; fi
for m in ${ms};do
  for restore in "_defaced" "_restore_defaced" "_restore_brain" "_bias";do
      nrestore=`echo $restore |sed -e 's:_defaced::g' |sed -e 's:_bias:_biasfield:g'`
      run $action restore/$m/${subj}${restore}.nii.gz $outputDerivedDir/${prefix}_${m}w${nrestore}.nii.gz
  done
done

# masks
run $action masks/$subj.nii.gz $outputDerivedDir/${prefix}_brainmask_drawem.nii.gz
run $action masks/$subj-bet.nii.gz $outputDerivedDir/${prefix}_brainmask_bet.nii.gz

# segmentations
for seg in all_labels tissue_labels;do
    run $action segmentations/${subj}_${seg}.nii.gz $outputDerivedDir/${prefix}_drawem_${seg}.nii.gz
done

# warps
ages="$age"
if [ $age != 40 ];then ages="$ages 40";fi
for cage in ${ages};do
  run mirtk convert-dof dofs/template-$cage-$subj-n.dof.gz $outputWarpDir/${prefix}_anat2std${cage}w.nii.gz -input-format mirtk -output-format fsl -target $code_dir/atlases/non-rigid-v2/T2/template-$cage.nii.gz -source $outputRawDir/${prefix}_T2w.nii.gz
  run mirtk convert-dof dofs/$subj-template-$cage-n.dof.gz $outputWarpDir/${prefix}_std${cage}w2anat.nii.gz -input-format mirtk -output-format fsl -source $code_dir/atlases/non-rigid-v2/T2/template-$cage.nii.gz -target $outputRawDir/${prefix}_T2w.nii.gz
done

# surfaces
surfdir=surfaces/$subj/workbench
for f in corrThickness curvature drawem inflated pial roi sphere sulc thickness white MyelinMap; do
  sfiles=`ls $surfdir/$subj.*$f*`
  for sf in ${sfiles};do
    so=`echo $sf | sed -e "s:$surfdir.::g"|sed -e "s:$subj.:${prefix}_:g"`
    # bids:
    so=`echo $so | sed -e 's:corrThickness:corr_thickness:g' | sed -e 's:SmoothedMyelinMap:smoothed_myelin_map:g' | sed -e 's:MyelinMap:myelin_map:g'`
    so=`echo $so | sed -e 's:.native::g' | sed -e 's:_L.:_left_:g'| sed -e 's:_R.:_right_:g'`
    
    run $action $sf $outputDerivedDir/Native/$so
  done
done


# original images
run cp $outputDerivedDir/${prefix}_T2w.nii.gz $outputRawDir/${prefix}_T2w.nii.gz

wbvols="T2w_restore"
wbmetrics="sulc thickness curvature corr_thickness"
wbsurfs="white pial midthickness inflated very_inflated sphere"

if [ -f T1/$subj.nii.gz ];then
  wbvols="$wbvols T1w_restore T1wdividedbyT2w T1wdividedbyT2w_ribbon"
  wbmetrics="$wbmetrics myelin_map smoothed_myelin_map"
  # myelin images etc.
  run $action $surfdir/$subj.ribbon.nii.gz $outputDerivedDir/${prefix}_ribbon.nii.gz
  run $action $surfdir/$subj.T1wDividedByT2w_defaced.nii.gz $outputDerivedDir/${prefix}_T1wdividedbyT2w.nii.gz
  run $action $surfdir/$subj.T1wDividedByT2w_ribbon.nii.gz $outputDerivedDir/${prefix}_T1wdividedbyT2w_ribbon.nii.gz

  # original images
  run mirtk transform-image masks/${subj}_mask_defaced.nii.gz masks/${subj}_mask_defaced_T1.nii.gz -target T1/$subj.nii.gz -dofin dofs/$subj-T2-T1-r.dof.gz -invert
  run fslmaths T1/${subj}.nii.gz -thr 0 -mul masks/${subj}_mask_defaced_T1.nii.gz $outputRawDir/${prefix}_T1w.nii.gz
  rm masks/${subj}_mask_defaced_T1.nii.gz
fi


# create spec file
cd $outputDerivedDir/Native

spec=${prefix}_wb.spec
rm -f $spec

for hi in {0..1}; do
  h=${Hemi[$hi]}
  C=${Cortex[$hi]}
  for surf in ${wbsurfs};do
    run wb_command -add-to-spec-file $spec $C ${prefix}_${h}_$surf.surf.gii
  done
done

C=INVALID
for metric in ${wbmetrics};do
    run wb_command -add-to-spec-file $spec $C ${prefix}_$metric.dscalar.nii
done
run wb_command -add-to-spec-file $spec $C ${prefix}_drawem.dlabel.nii

for file in ${wbvols};do
  run wb_command -add-to-spec-file $spec $C ../${prefix}_$file.nii.gz
done



if [ ! $minimal -eq 1 ];then
  # segmentations
  seg=labels
  run $action segmentations/${subj}_${seg}.nii.gz $outputDerivedDir/${prefix}_drawem_${seg}.nii.gz
  
  # warps
  for cage in ${ages};do
    run mirtk convert-dof dofs/template-$cage-$subj-n.dof.gz dofs/template-$cage-$subj-r.dof.gz -input-format mirtk -output-format rigid
    run mirtk convert-dof dofs/$subj-template-$cage-n.dof.gz dofs/$subj-template-$cage-r.dof.gz -input-format mirtk -output-format rigid

    run mirtk convert-dof dofs/template-$cage-$subj-r.dof.gz $outputWarpDir/${prefix}_anat2std${cage}w.mat -input-format mirtk -output-format fsl -target $code_dir/atlases/non-rigid-v2/T2/template-$cage.nii.gz -source $outputRawDir/${prefix}_T2w.nii.gz
    run mirtk convert-dof dofs/$subj-template-$cage-r.dof.gz $outputWarpDir/${prefix}_std${cage}w2anat.mat -input-format mirtk -output-format fsl -source $code_dir/atlases/non-rigid-v2/T2/template-$cage.nii.gz -target $outputRawDir/${prefix}_T2w.nii.gz

    run $action dofs/template-$cage-$subj-r.dof.gz $outputWarpDir/${prefix}_anat2std${cage}w-r.dof.gz
    run $action dofs/$subj-template-$cage-r.dof.gz $outputWarpDir/${prefix}_std${cage}w2anat-r.dof.gz

    run $action dofs/template-$cage-$subj-n.dof.gz $outputWarpDir/${prefix}_anat2std${cage}w-n.dof.gz
    run $action dofs/$subj-template-$cage-n.dof.gz $outputWarpDir/${prefix}_std${cage}w2anat-n.dof.gz
  done
  
  run mirtk convert-dof dofs/$subj-MNI-n.dof.gz dofs/$subj-MNI-r.dof.gz -input-format mirtk -output-format rigid
  run mirtk convert-dof dofs/$subj-MNI-n.dof.gz $outputWarpDir/${prefix}_MNI2anat.nii.gz -input-format mirtk -output-format fsl -target $outputRawDir/${prefix}_T2w.nii.gz -source $MNI_T1
  run mirtk convert-dof dofs/$subj-MNI-r.dof.gz $outputWarpDir/${prefix}_MNI2anat.mat -input-format mirtk -output-format fsl -target $outputRawDir/${prefix}_T2w.nii.gz -source $MNI_T1
  run $action dofs/$subj-MNI-n.dof.gz $outputWarpDir/${prefix}_MNI2anat-n.dof.gz
  run $action dofs/$subj-MNI-r.dof.gz $outputWarpDir/${prefix}_MNI2anat-r.dof.gz

  if [ -f T1/$subj.nii.gz ];then
    run mirtk convert-dof dofs/$subj-T2-T1-r.dof.gz $outputWarpDir/${prefix}_T1w2anat.mat -input-format mirtk -output-format fsl -target $outputRawDir/${prefix}_T2w.nii.gz -source $outputRawDir/${prefix}_T1w.nii.gz
    run $action dofs/$subj-T2-T1-r.dof.gz $outputWarpDir/${prefix}_T1w2anat-r.dof.gz
  fi

  # copy posteriors
  outputPostDir=$outputDerivedDir/posteriors
  mkdir -p $outputPostDir
  structs=`ls posteriors`
  for str in ${structs};do
    run $action posteriors/$str/$subj.nii.gz $outputPostDir/${prefix}_drawem_${str}.nii.gz
  done


fi
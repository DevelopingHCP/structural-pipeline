#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject [options]
This script computes the different measurements for the dHCP structural pipeline.

Arguments:
  subject                       Subject ID

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -h / -help / --help           Print usage.
"
  exit;
}

run(){
  echo "$@" >>$log 2>>$err
  "$@" >>$log 2>>$err 
  if [ ! $? -eq 0 ]; then
    echo " failed: see log file $err for details"
    exit 1
  fi
}



################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
subj=$1

datadir=`pwd`

while [ $# -gt 0 ]; do
  case "$2" in
    -d|-data-dir)  shift; datadir=$2; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "measurements for the dHCP pipeline
Subject:    $subj 
Directory:  $datadir 

$BASH_SOURCE $command
----------------------------"


cd $datadir

log=logs/$subj-measures.log
err=logs/$subj-measures.error
rm -f $log $err

outvtk=surfaces/$subj/vtk
outtmp=surfaces/$subj/temp
segdir=segmentations

statdir=measures
rdir=$statdir/surfaces
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p $rdir $statdir $statdir/$subj




# do the volume-based measurements
super_structures=$scriptdir/../../../label_names/super-structures.csv
run $scriptdir/volume-measurements.sh $subj $statdir/$subj/$subj $super_structures

if [ ! -f $outvtk/$subj.L.white.native.surf.vtk ];then echo "The left WM surface for subject $subj doesn't exist"; exit;fi
if [ ! -f $outvtk/$subj.R.white.native.surf.vtk ];then echo "The right WM surface for subject $subj doesn't exist"; exit;fi

# gather all measurements into a single file
if [ ! -f $rdir/$subj.white.native.surf.vtk ];then
  for h in L R;do
    if [ ! -f $rdir/$subj.$h.white.native.surf.vtk ];then
      tmpsurf=$rdir/$subj.$h.white.native.surf-temp.vtk

      # calculate curvature
      run cp $outvtk/$subj.$h.white.native.surf.vtk $tmpsurf
      run mirtk calculate-surface-attributes $tmpsurf $tmpsurf -H MeanCurvature -smooth-weighting Combinatorial -smooth-iterations 10 -vtk-curvatures 
      run mirtk calculate-surface-attributes $tmpsurf $tmpsurf -H GaussCurvature -smooth-weighting Combinatorial -smooth-iterations 10 -vtk-curvatures 
      run mirtk calculate $tmpsurf -mul -1 -scalars MeanCurvature -out $tmpsurf
      run mirtk calculate $tmpsurf -mul -1 -scalars GaussCurvature -out $tmpsurf

      # calculate thickness
      run mirtk evaluate-distance $tmpsurf $outvtk/$subj.$h.pial.native.surf.vtk $tmpsurf -name Thickness -index

      # calculate normalised sulcal depth
      # mean=`mirtk calculate $outvtk/$subj.$h.inflated_for_sphere.native.surf.vtk -mean -scalars SulcalDepth |cut -d'=' -f2`
      # std=`mirtk calculate $outvtk/$subj.$h.inflated_for_sphere.native.surf.vtk -std -scalars SulcalDepth |cut -d'=' -f2`
      # run mirtk calculate $outvtk/$subj.$h.inflated_for_sphere.native.surf.vtk -sub $mean -div $std -scalars SulcalDepth -out $outvtk/$h.sulc.vtk
      # run mirtk copy-pointset-attributes $outvtk/$h.sulc.vtk $tmpsurf $tmpsurf -pointdata SulcalDepth
      # run rm $outvtk/$h.sulc.vtk
      
      # copy sulcal depth
      run mirtk copy-pointset-attributes $outvtk/$subj.$h.inflated_for_sphere.native.surf.vtk $tmpsurf $tmpsurf -pointdata SulcalDepth

      # copy labels
      run mirtk copy-pointset-attributes $outvtk/$subj.$h.drawem.native.label.vtk $tmpsurf $tmpsurf -pointdata Labels

      run mv $tmpsurf $rdir/$subj.$h.white.native.surf.vtk
    fi
  done

  run mirtk convert-pointset $rdir/$subj.L.white.native.surf.vtk $rdir/$subj.R.white.native.surf.vtk $rdir/$subj.white.native.surf.vtk
  rm $rdir/$subj.L.white.native.surf.vtk $rdir/$subj.R.white.native.surf.vtk
fi

# project labels to pial
if [ ! -f $rdir/$subj.pial.native.surf.vtk ];then
  for h in L R;do
    run mirtk copy-pointset-attributes $outvtk/$subj.$h.drawem.native.label.vtk $outvtk/$subj.$h.pial.native.surf.vtk $rdir/$subj.$h.pial.native.surf.vtk -pointdata Labels
  done
  run mirtk convert-pointset $rdir/$subj.L.pial.native.surf.vtk $rdir/$subj.R.pial.native.surf.vtk $rdir/$subj.pial.native.surf.vtk
fi

# compute the convex hull
if [ ! -f $rdir/$subj.outerpial.native.surf.vtk ];then 
  for h in L R;do
    if [ ! -f $rdir/$subj.$h.outerpial.native.surf.vtk ];then
      # compute outside surface for GI
      run mirtk dilate-image $segdir/${subj}_${h}_pial.nii.gz $rdir/${subj}_${h}_outerpial.nii.gz -iterations 3
      run mirtk erode-image $rdir/${subj}_${h}_outerpial.nii.gz $rdir/${subj}_${h}_outerpial.nii.gz -iterations 2
      run mirtk extract-surface $rdir/${subj}_${h}_outerpial.nii.gz $rdir/$subj.$h.outerpial.native.surf-temp.vtk -isovalue 0.5 -blur 1 
      # project labels
      run mirtk project-onto-surface $rdir/$subj.$h.outerpial.native.surf-temp.vtk $rdir/$subj.$h.outerpial.native.surf.vtk -surface $rdir/$subj.$h.pial.native.surf.vtk -scalars Labels
      run rm $rdir/${subj}_${h}_outerpial.nii.gz $rdir/$subj.$h.outerpial.native.surf-temp.vtk
    fi
  done  
  run mirtk convert-pointset $rdir/$subj.L.outerpial.native.surf.vtk $rdir/$subj.R.outerpial.native.surf.vtk $rdir/$subj.outerpial.native.surf.vtk
  run rm $rdir/$subj.L.outerpial.native.surf.vtk $rdir/$subj.R.outerpial.native.surf.vtk $rdir/$subj.L.pial.native.surf.vtk $rdir/$subj.R.pial.native.surf.vtk
fi

# measure GI
run $scriptdir/GI-measurements.sh $rdir/$subj.pial.native.surf.vtk $rdir/$subj.outerpial.native.surf.vtk $statdir/$subj/$subj $super_structures

# do the surface-based measurements (convex-hull norm)
run $scriptdir/surface-measurements.sh $rdir/$subj.white.native.surf.vtk $rdir/$subj.outerpial.native.surf.vtk $statdir/$subj/$subj $super_structures

#clean-up
rm $rdir/$subj.*
rmdir $rdir   2> /dev/null

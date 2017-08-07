#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject age [options]
This script runs the dHCP surface pipeline.

Arguments:
  subject                       Subject ID

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}

# log function for hemispheres
runhemisphere()
{
  log=logs/$subj.surface.$h-hemisphere.log
  err=logs/$subj.surface.$h-hemisphere.log
  echo "$@"
  "$@" >$log 2>$err
  if [ ! $? -eq 0 ]; then
    echo "failed: see log files $log , $err for details"
    exit 1
  fi
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
subj=$1

datadir=`pwd`
threads=1

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/parameters/configuration.sh

shift
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

echo "dHCP Surface pipeline
Subject:    $subj 
Directory:  $datadir 
Threads:    $threads

$BASH_SOURCE $command
----------------------------"

################ PIPELINE ################

cd $datadir

surfacedir=surfaces
segdir=segmentations
outwb=$surfacedir/$subj/workbench
outvtk=$surfacedir/$subj/vtk
outtmp=$surfacedir/$subj/temp

mkdir -p $outvtk $outwb $outtmp logs


Hemi=('L' 'R');
Cortex=('CORTEX_LEFT' 'CORTEX_RIGHT');
Surf=('white' 'pial' 'midthickness' 'inflated' 'very_inflated' 'sphere');


# reconstruct surfaces
completed=1
for surf in white pial;do
    for h in L R;do
        if [ ! -f $outvtk/$subj.$h.$surf.native.surf.vtk ];then 
            completed=0
        fi
    done
done

if [ $completed -eq 0 ]; then 
    run mirtk recon-neonatal-cortex -v --threads=$threads --config="$surface_recon_config" --sessions="$subj" --prefix="$outvtk/$subj" --temp="$outvtk/temp-recon/$subj" --white --pial
    rm -r $outvtk/temp-recon
fi


# create files of each hemisphere
for hi in {0..1}; do
    h=${Hemi[$hi]}
    runhemisphere $codedir/process-surfaces-hemisphere.sh $subj $h $segdir $outvtk $outwb $outtmp &
    if [ $threads -eq 1 ];then wait;fi
done
if [ $threads -gt 1 ];then wait;fi


# create files for both hemispheres for workbench
if  [ ! -f $outwb/$subj.sulc.native.dscalar.nii ];then
  run wb_command -cifti-create-dense-scalar $outwb/temp.$subj.sulc.native.dscalar.nii -left-metric $outwb/$subj.L.sulc.native.shape.gii -right-metric $outwb/$subj.R.sulc.native.shape.gii
  run wb_command -set-map-names $outwb/temp.$subj.sulc.native.dscalar.nii -map 1 "${subj}_Sulc"
  run wb_command -cifti-palette $outwb/temp.$subj.sulc.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE $outwb/temp.$subj.sulc.native.dscalar.nii -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
  run mv $outwb/temp.$subj.sulc.native.dscalar.nii $outwb/$subj.sulc.native.dscalar.nii
fi
      
if  [ ! -f $outwb/$subj.curvature.native.dscalar.nii ];then
  run wb_command -cifti-create-dense-scalar $outwb/temp.$subj.curvature.native.dscalar.nii -left-metric $outwb/$subj.L.curvature.native.shape.gii -roi-left $outwb/$subj.L.roi.native.shape.gii -right-metric $outwb/$subj.R.curvature.native.shape.gii -roi-right $outwb/$subj.R.roi.native.shape.gii
  run wb_command -set-map-names $outwb/temp.$subj.curvature.native.dscalar.nii -map 1 "${subj}_Curvature"
  run wb_command -cifti-palette $outwb/temp.$subj.curvature.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE $outwb/temp.$subj.curvature.native.dscalar.nii -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
  run mv $outwb/temp.$subj.curvature.native.dscalar.nii $outwb/$subj.curvature.native.dscalar.nii
fi

if  [ ! -f $outwb/$subj.thickness.native.dscalar.nii ];then
  run wb_command -cifti-create-dense-scalar $outwb/temp.$subj.thickness.native.dscalar.nii -left-metric $outwb/$subj.L.thickness.native.shape.gii -roi-left $outwb/$subj.L.roi.native.shape.gii -right-metric $outwb/$subj.R.thickness.native.shape.gii -roi-right $outwb/$subj.R.roi.native.shape.gii
  run wb_command -set-map-names $outwb/temp.$subj.thickness.native.dscalar.nii -map 1 "${subj}_Thickness"
  run wb_command -cifti-palette $outwb/temp.$subj.thickness.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE $outwb/temp.$subj.thickness.native.dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
  run mv $outwb/temp.$subj.thickness.native.dscalar.nii $outwb/$subj.thickness.native.dscalar.nii
fi

if  [ ! -f $outwb/$subj.corr_thickness.native.dscalar.nii ];then
  run wb_command -cifti-create-dense-scalar $outwb/temp.$subj.corrThickness.native.dscalar.nii -left-metric $outwb/$subj.L.corrThickness.native.shape.gii -roi-left $outwb/$subj.L.roi.native.shape.gii -right-metric $outwb/$subj.R.corrThickness.native.shape.gii -roi-right $outwb/$subj.R.roi.native.shape.gii
  run wb_command -set-map-names $outwb/temp.$subj.corrThickness.native.dscalar.nii -map 1 "${subj}_corrThickness"
  run wb_command -cifti-palette $outwb/temp.$subj.corrThickness.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE $outwb/temp.$subj.corrThickness.native.dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
  run mv $outwb/temp.$subj.corrThickness.native.dscalar.nii $outwb/$subj.corrThickness.native.dscalar.nii
fi

if [ ! -f $outwb/$subj.drawem.native.dlabel.nii ];then
  run wb_command -cifti-create-label $outwb/temp.$subj.drawem.native.dlabel.nii -left-label $outwb/$subj.L.drawem.native.label.gii -roi-left $outwb/$subj.L.roi.native.shape.gii -right-label $outwb/$subj.R.drawem.native.label.gii -roi-right $outwb/$subj.R.roi.native.shape.gii
  run wb_command -set-map-names $outwb/temp.$subj.drawem.native.dlabel.nii -map 1 ${subj}_drawem
  run mv $outwb/temp.$subj.drawem.native.dlabel.nii $outwb/$subj.drawem.native.dlabel.nii
fi

# create myelin map etc.
if [ -f restore/T1/$subj.nii.gz ];then 
  run $codedir/create-myelin-map.sh $subj

  for STRINGII in MyelinMap@func SmoothedMyelinMap@func; do
    Map=`echo $STRINGII | cut -d "@" -f 1`
    Ext=`echo $STRINGII | cut -d "@" -f 2`    
    if  [ ! -f $outwb/$subj.$Map.native.dscalar.nii ];then
      run wb_command -cifti-create-dense-scalar $outwb/temp.$subj.$Map.native.dscalar.nii -left-metric $outwb/$subj.L.$Map.native."$Ext".gii -roi-left $outwb/$subj.L.roi.native.shape.gii -right-metric $outwb/$subj.R.${Map}.native."$Ext".gii -roi-right $outwb/$subj.R.roi.native.shape.gii
      run wb_command -set-map-names $outwb/temp.$subj.$Map.native.dscalar.nii -map 1 "${subj}_${Map}"
      run wb_command -cifti-palette $outwb/temp.$subj.$Map.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE $outwb/temp.$subj.$Map.native.dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
      run mv $outwb/temp.$subj.$Map.native.dscalar.nii $outwb/$subj.$Map.native.dscalar.nii
    fi
  done
  if [ ! -f $outwb/$subj.T1.nii.gz ];then 
    ln restore/T1/${subj}_restore_defaced.nii.gz $outwb/$subj.T1.nii.gz
  fi
fi

if [ ! -f $outwb/$subj.T2.nii.gz ];then 
  ln restore/T2/${subj}_restore_defaced.nii.gz $outwb/$subj.T2.nii.gz
fi

# add them to .spec file
run cd $outwb
rm -f $subj.native.wb.spec

for hi in {0..1}; do
    h=${Hemi[$hi]}
    C=${Cortex[$hi]}

    for surf in "${Surf[@]}"; do
      if [ -f $subj.$h.$surf.native.surf.gii ];then
        run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.$h.$surf.native.surf.gii
      fi
    done
done

C=INVALID
run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.sulc.native.dscalar.nii
run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.curvature.native.dscalar.nii
run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.thickness.native.dscalar.nii
run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.corrThickness.native.dscalar.nii
run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.drawem.native.dlabel.nii
run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.T2.nii.gz


if [ -f restore/T1/$subj.nii.gz ];then 
  run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.T1.nii.gz
  run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.T1wDividedByT2w_defaced.nii.gz
  run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.T1wDividedByT2w_ribbon.nii.gz
  run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.MyelinMap.native.dscalar.nii
  run wb_command -add-to-spec-file $subj.native.wb.spec $C $subj.SmoothedMyelinMap.native.dscalar.nii
fi
  
#!/bin/bash

[ $# -ge 6 ] || { echo "usage: $(basename "$0") <subject> <hemisphere(L/R)> <segmentation_dir> <output_vtk_dir> <output_wb_dir> <output_temp_dir>"; exit 1; }
subj=$1
h=$2
segdir=$3
outvtk=$4
outwb=$5
outtmp=$6


if [ "$h" == "L" ];then
C='CORTEX_LEFT'
elif [ "$h" == "R" ];then
C='CORTEX_RIGHT';
else 
echo "hemisphere must be either L or R";exit 1;
fi
hs=`echo $h | tr '[:upper:]' '[:lower:]'`h


mkdir -p $outvtk $outwb $outtmp


surfvars(){
    surf=${Surf[$si]}
    T=${Type[$si]}
    T2=${Type2[$si]}
}

vtktogii(){
    vtk=$1
    gii=$2
    giiT=$3
    giiT2=$4
    giibase=`basename $gii`; giidir=`echo $gii|sed -e "s:$giibase::g"`; tempgii=$giidir/temp-$giibase
    run mirtk convert-pointset $vtk $tempgii
    run wb_command -set-structure $tempgii $C -surface-type $giiT -surface-secondary-type $giiT2
    run mv $tempgii $gii
}

giimap(){
    vtk=$1
    gii=$2
    scalars=$3
    mapname=$4
    giibase=`basename $gii`; giidir=`echo $gii|sed -e "s:$giibase::g"`; tempgii=$giidir/temp-$giibase; tempvtk=$tempgii.vtk
    run mirtk delete-pointset-attributes $vtk $tempvtk -all
    run mirtk copy-pointset-attributes $vtk $tempvtk $tempgii -pointdata $scalars curv
    run rm $tempvtk
    run wb_command -set-structure  $tempgii $C
    run wb_command -metric-math "var * -1" $tempgii -var var $tempgii
    run wb_command -set-map-name  $tempgii 1 ${subj}_${h}_${mapname}
    run wb_command -metric-palette $tempgii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
    if [ "$mapname" == "Thickness" ];then
      run wb_command -metric-math "abs(thickness)" $tempgii -var thickness $tempgii
      run wb_command -metric-palette $tempgii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
    fi
    run mv $tempgii $gii
}

cleanup(){
    rm -f $outvtk/$hs.*
}



echo "process surfaces for $h hemisphere"




###################### WHITE SURFACE ###################################################################

surf='white'
if  [ ! -f $outwb/$subj.$h.$surf.native.surf.gii ];then
  vtktogii $outvtk/$subj.$h.$surf.native.surf.vtk $outwb/$subj.$h.$surf.native.surf.gii ANATOMICAL GRAY_WHITE
fi

if  [ ! -f $outwb/$subj.$h.curvature.native.shape.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Process $h curvature"
  run mirtk calculate-surface-attributes $outvtk/$subj.$h.$surf.native.surf.vtk $outvtk/$hs.curvature.vtk -H Curvature -smooth-weighting Combinatorial -smooth-iterations 10 -vtk-curvatures 
  run mirtk calculate $outvtk/$hs.curvature.vtk -mul -1 -scalars Curvature -out $outvtk/$hs.curvature.vtk
  giimap $outvtk/$hs.curvature.vtk $outwb/$subj.$h.curvature.native.shape.gii Curvature Curvature
  run wb_command -metric-dilate $outwb/$subj.$h.curvature.native.shape.gii $outwb/$subj.$h.$surf.native.surf.gii 10 $outwb/$subj.$h.curvature.native.shape.gii -nearest
fi


###################### PIAL SURFACE ###################################################################

surf='pial'
if  [ ! -f $outwb/$subj.$h.$surf.native.surf.gii ];then
  vtktogii $outvtk/$subj.$h.$surf.native.surf.vtk $outwb/$subj.$h.$surf.native.surf.gii ANATOMICAL PIAL
fi


###################### MID-THICKNESS SURFACE ###################################################################

insurf1='white'; insurf2='pial'; surf='midthickness'
if  [ ! -f $outwb/$subj.$h.$surf.native.surf.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Extract $h mid-thickness surface"
  run mid-surface $outvtk/$subj.$h.$insurf1.native.surf.vtk $outvtk/$subj.$h.$insurf2.native.surf.vtk $outvtk/$subj.$h.$surf.native.surf.vtk -ascii
  vtktogii $outvtk/$subj.$h.$surf.native.surf.vtk $outwb/$subj.$h.$surf.native.surf.gii ANATOMICAL MIDTHICKNESS
fi

if  [ ! -f $outwb/$subj.$h.thickness.native.shape.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Process $h thickness"
  run mirtk evaluate-distance $outvtk/$subj.$h.$insurf1.native.surf.vtk $outvtk/$subj.$h.$insurf2.native.surf.vtk $outvtk/$hs.dist1.vtk -name Thickness
  run mirtk evaluate-distance $outvtk/$subj.$h.$insurf2.native.surf.vtk $outvtk/$subj.$h.$insurf1.native.surf.vtk $outvtk/$hs.dist2.vtk -name Thickness
  run mirtk calculate $outvtk/$hs.dist1.vtk -scalars Thickness -add $outvtk/$hs.dist2.vtk Thickness -div 2 -o $outvtk/$hs.thickness.vtk
  giimap $outvtk/$hs.thickness.vtk $outwb/$subj.$h.thickness.native.shape.gii Thickness Thickness
  run wb_command -metric-dilate $outwb/$subj.$h.thickness.native.shape.gii $outwb/$subj.$h.$insurf1.native.surf.gii 10 $outwb/$subj.$h.thickness.native.shape.gii -nearest
fi

###################### INFLATED SURFACE ###################################################################

insurf='white'; surf='inflated_for_sphere'
if  [ ! -f $outwb/$subj.$h.sulc.native.shape.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Extract $h inflated surface from white (for sphere)"
  run mirtk deform-mesh $outvtk/$subj.$h.$insurf.native.surf.vtk $outvtk/$subj.$h.$surf.native.surf.vtk -inflate-brain -track SulcalDepth
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Process $h sulcal depth"
  giimap $outvtk/$subj.$h.$surf.native.surf.vtk $outwb/$subj.$h.sulc.native.shape.gii SulcalDepth Sulc
fi

insurf='midthickness'; surf='inflated'; surf2='very_inflated'
if  [ ! -f $outvtk/$subj.$h.$surf2.native.surf.vtk ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Extract $h inflated surface from midthickness (for workbench)"
  run wb_command -surface-generate-inflated $outwb/$subj.$h.$insurf.native.surf.gii $outwb/$subj.$h.$surf.native.surf.gii $outwb/$subj.$h.$surf2.native.surf.gii -iterations-scale 2.5
  run mirtk convert-pointset $outwb/$subj.$h.$surf.native.surf.gii $outvtk/$subj.$h.$surf.native.surf.vtk
  run mirtk convert-pointset $outwb/$subj.$h.$surf2.native.surf.gii $outvtk/$subj.$h.$surf2.native.surf.vtk
fi


###################### SPHERICAL SURFACE ###################################################################

insurf1='white'; insurf2='inflated_for_sphere'; surf='sphere'
if  [ ! -f $outwb/$subj.$h.$surf.native.surf.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Extract $h spherical surface"
  # need to replace the following with run
  comm="mesh-to-sphere $outvtk/$subj.$h.$insurf1.native.surf.vtk $outvtk/$subj.$h.$surf.native.surf.vtk -inflated $outvtk/$subj.$h.$insurf2.native.surf.vtk -parin $parameters_dir/spherical-mesh.cfg"
  echo $comm
  $comm
  vtktogii $outvtk/$subj.$h.$surf.native.surf.vtk $outwb/$subj.$h.$surf.native.surf.gii SPHERICAL GRAY_WHITE
fi


###################### LABELS ###################################################################


insurf1='midthickness'; insurf2='white'; surf='drawem'
if  [ ! -f $outwb/$subj.$h.$surf.native.label.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Project $h Draw-EM labels"
  # exclude csf,out and dilate tissues to cover space
  run mirtk padding $segdir/${subj}_tissue_labels.nii.gz $segdir/${subj}_tissue_labels.nii.gz $outvtk/$hs.mask.nii.gz 2 $CSF_label $BG_label 0 
  run dilate-labels $outvtk/$hs.mask.nii.gz $outvtk/$hs.mask.nii.gz -blur 1
  # exclude subcortical structures and dilate cortical labels to cover space
  run mirtk padding $segdir/${subj}_labels.nii.gz $segdir/${subj}_labels.nii.gz $outvtk/$hs.labels.nii.gz `echo $cortical_structures|wc -w` $cortical_structures 0 -invert
  if [ "$h" == "L" ];then oh=R;else oh=L;fi
  run mirtk padding $outvtk/$hs.labels.nii.gz $segdir/${subj}_${oh}_pial.nii.gz $outvtk/$hs.labels.nii.gz 1 0 
  run dilate-labels $outvtk/$hs.labels.nii.gz $outvtk/$hs.labels.nii.gz -blur 1

  # project to surface
  run mirtk padding $outvtk/$hs.labels.nii.gz $outvtk/$hs.mask.nii.gz $outvtk/$hs.labels.nii.gz 2 2 3 -100 -invert
  run extend-image-slices $outvtk/$hs.labels.nii.gz $outvtk/$hs.labels.ext.nii.gz -xyz 10
  # TODO: replace the next (uncommented) line with the following
  run mirtk project-onto-surface $outvtk/$subj.$h.$insurf1.native.surf.vtk $outvtk/$subj.$h.$surf.native.label.vtk -labels $outvtk/$hs.labels.ext.nii.gz -name curv -pointdata -smooth 10 -fill -min-ratio 0.05 
  # run surface-assign-labels $outvtk/$subj.$h.$insurf1.native.surf.vtk $outvtk/$subj.$h.$surf.native.label.vtk -labels $outvtk/$hs.labels.ext.nii.gz -name curv -pointdata -smooth 10 -fill -min-ratio 0.05 
  
  # mask out the subcortical structures (both original and dilated)
  run mirtk copy-pointset-attributes $outvtk/$subj.$h.$insurf2.native.surf.vtk $outvtk/$subj.$h.$surf.native.label.vtk -celldata-as-pointdata RegionId
  run mirtk calculate $outvtk/$subj.$h.$surf.native.label.vtk -scalars RegionId -clamp 0 1 -mul curv -clamp-lt 0 -out $outvtk/$subj.$h.$surf.native.label.vtk int curv
  run mirtk convert-pointset $outvtk/$subj.$h.$surf.native.label.vtk $outvtk/$hs.labels.shape.gii
  run mirtk copy-pointset-attributes $outvtk/$subj.$h.$surf.native.label.vtk $outvtk/$subj.$h.$surf.native.label.vtk -pointdata curv Labels
  run mirtk delete-pointset-attributes $outvtk/$subj.$h.$surf.native.label.vtk $outvtk/$subj.$h.$surf.native.label.vtk -pointdata curv -pointdata RegionId

  run wb_command -metric-label-import $outvtk/$hs.labels.shape.gii $LUT $outwb/temp.$subj.$h.$surf.native.label.gii -drop-unused-labels
  run wb_command -set-structure $outwb/temp.$subj.$h.$surf.native.label.gii $C
  run wb_command -set-map-names $outwb/temp.$subj.$h.$surf.native.label.gii -map 1 ${subj}_${h}_${surf}
  mv $outwb/temp.$subj.$h.$surf.native.label.gii $outwb/$subj.$h.$surf.native.label.gii
fi

insurf2=drawem
if  [ ! -f $outwb/$subj.$h.roi.native.shape.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Process $h roi"
  run wb_command -metric-math "(Labels > 0) * (thickness>0)" $outwb/temp.$subj.$h.roi.native.shape.gii -var Labels  $outwb/$subj.$h.$insurf2.native.label.gii -var thickness $outwb/$subj.$h.thickness.native.shape.gii
  run wb_command -metric-fill-holes $outwb/$subj.$h.$insurf1.native.surf.gii $outwb/temp.$subj.$h.roi.native.shape.gii $outwb/temp.$subj.$h.roi.native.shape.gii
  run wb_command -metric-remove-islands $outwb/$subj.$h.$insurf1.native.surf.gii $outwb/temp.$subj.$h.roi.native.shape.gii $outwb/temp.$subj.$h.roi.native.shape.gii
  run wb_command -set-map-names $outwb/temp.$subj.$h.roi.native.shape.gii -map 1 ${subj}_${h}_ROI
  mv $outwb/temp.$subj.$h.roi.native.shape.gii $outwb/$subj.$h.roi.native.shape.gii
fi

if  [ ! -f $outwb/$subj.$h.corrThickness.native.shape.gii ];then
  echo
  echo "-------------------------------------------------------------------------------------"
  echo "Process $h corr thickness"
  run wb_command -metric-regression $outwb/$subj.$h.thickness.native.shape.gii $outwb/$subj.$h.corrThickness.native.shape.gii -roi $outwb/$subj.$h.roi.native.shape.gii -remove $outwb/$subj.$h.curvature.native.shape.gii
  run wb_command -set-map-name $outwb/$subj.$h.corrThickness.native.shape.gii 1 ${subj}_${h}_corrThickness
  run wb_command -metric-palette $outwb/$subj.$h.corrThickness.native.shape.gii MODE_USER_SCALE -pos-user 1 1.7 -neg-user 0 0 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
fi

cleanup

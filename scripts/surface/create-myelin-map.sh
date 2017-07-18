#!/bin/bash

subj=$1

run(){
  echo "$@"
  "$@"
  if [ ! $? -eq 0 ]; then
    echo "failed"
    exit 1
  fi
}

T1=restore/T1/${subj}.nii.gz
T2=restore/T2/${subj}.nii.gz
outwb=surfaces/$subj/workbench
outtmp=surfaces/$subj/temp


LeftGreyRibbonValue="3"
LeftGreyRibbonValueIn="2"
RightGreyRibbonValue="42"
RightGreyRibbonValueIn="41"

MyelinMappingFWHM="5"
SurfaceSmoothingFWHM="4"
MyelinMappingSigma=`echo "$MyelinMappingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
SurfaceSmoothingSigma=`echo "$SurfaceSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`


if [ -f $T1 ] ; then

    if [ ! -f $outwb/$subj.ribbon.nii.gz ];then 
        # create ribbon
        for h in L R ; do
            run wb_command -create-signed-distance-volume $outwb/$subj.$h.pial.native.surf.gii $T2 $outtmp/dist_$h.nii.gz
            run fslmaths $outtmp/dist_$h.nii.gz -uthr 0 -abs -bin $outtmp/dist_$h.nii.gz
            run fslmaths segmentations/${subj}_tissue_labels.nii.gz -mul $outtmp/dist_$h.nii.gz $outtmp/tissue_labels_$h.nii.gz
        done

        run mirtk padding $outtmp/tissue_labels_L.nii.gz $outtmp/tissue_labels_L.nii.gz $outtmp/in_L.nii.gz 2 $CSF_label $CGM_label 0
        run fslmaths $outtmp/in_L.nii.gz -bin -mul $LeftGreyRibbonValueIn $outtmp/in_L.nii.gz
        run fslmaths $outtmp/tissue_labels_L.nii.gz -thr $CGM_label -uthr $CGM_label -bin -mul $LeftGreyRibbonValue $outtmp/out_L.nii.gz

        run mirtk padding $outtmp/tissue_labels_R.nii.gz $outtmp/tissue_labels_R.nii.gz $outtmp/in_R.nii.gz 2 $CSF_label $CGM_label 0
        run fslmaths $outtmp/in_R.nii.gz -bin -mul $RightGreyRibbonValueIn $outtmp/in_R.nii.gz
        run fslmaths $outtmp/tissue_labels_R.nii.gz -thr $CGM_label -uthr $CGM_label -bin -mul $RightGreyRibbonValue $outtmp/out_R.nii.gz

        run fslmaths $outtmp/in_L.nii.gz -add $outtmp/in_R.nii.gz -add $outtmp/out_L.nii.gz -add $outtmp/out_R.nii.gz $outwb/$subj.ribbon.nii.gz

        for h in L R ; do
            rm $outtmp/dist_$h.nii.gz $outtmp/tissue_labels_$h.nii.gz $outtmp/in_$h.nii.gz $outtmp/out_$h.nii.gz
        done
    fi

    # get T1/T2 ratio
    if [ ! -f $outwb/$subj.T1wDividedByT2w_ribbon.nii.gz ];then 
        run wb_command -volume-math "clamp((T1w / T2w), 0, 100)"  $outwb/$subj.T1wDividedByT2w.nii.gz -var T1w $T1 -var T2w $T2 -fixnan 0
        run wb_command -volume-palette $outwb/$subj.T1wDividedByT2w.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
        run fslmaths $outwb/$subj.T1wDividedByT2w.nii.gz -mul masks/${subj}_mask_defaced.nii.gz $outwb/$subj.T1wDividedByT2w_defaced.nii.gz

        run wb_command -volume-math "(T1w / T2w) * (((ribbon > ($LeftGreyRibbonValue - 0.01)) * (ribbon < ($LeftGreyRibbonValue + 0.01))) + ((ribbon > ($RightGreyRibbonValue - 0.01)) * (ribbon < ($RightGreyRibbonValue + 0.01))))" $outwb/$subj.T1wDividedByT2w_ribbon.nii.gz -var T1w $T1 -var T2w $T2 -var ribbon $outwb/$subj.ribbon.nii.gz
        run wb_command -volume-palette $outwb/$subj.T1wDividedByT2w_ribbon.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
    fi

    for h in L R ; do
        if [ $h = "L" ] ; then 
            ribbon="$LeftGreyRibbonValue"
        elif [ $h = "R" ] ; then 
            ribbon="$RightGreyRibbonValue"
        fi

        if [ ! -f $outwb/$subj.$h.SmoothedMyelinMap.native.func.gii ];then
            run wb_command -volume-math "(ribbon > ($ribbon - 0.01)) * (ribbon < ($ribbon + 0.01))" $outtmp/temp_ribbon.nii.gz -var ribbon $outwb/$subj.ribbon.nii.gz
            run wb_command -volume-to-surface-mapping  $outwb/$subj.T1wDividedByT2w.nii.gz  $outwb/$subj.$h.midthickness.native.surf.gii $outwb/$subj.$h.MyelinMap.native.func.gii -myelin-style $outtmp/temp_ribbon.nii.gz  $outwb/$subj.$h.thickness.native.shape.gii "$MyelinMappingSigma"
            run wb_command -metric-dilate $outwb/$subj.$h.MyelinMap.native.func.gii $outwb/$subj.$h.midthickness.native.surf.gii 10 $outwb/$subj.$h.MyelinMap.native.func.gii -nearest -data-roi $outwb/$subj.$h.roi.native.shape.gii
            rm $outtmp/temp_ribbon.nii.gz

            run wb_command -metric-smoothing $outwb/$subj.$h.midthickness.native.surf.gii $outwb/$subj.$h.MyelinMap.native.func.gii "$SurfaceSmoothingSigma" $outwb/$subj.$h.SmoothedMyelinMap.native.func.gii -roi $outwb/$subj.$h.roi.native.shape.gii 
        
            for STRING in MyelinMap@func SmoothedMyelinMap@func ; do
                Map=`echo $STRING | cut -d "@" -f 1`
                Ext=`echo $STRING | cut -d "@" -f 2`
                run wb_command -set-map-name $outwb/$subj.$h.${Map}.native.$Ext.gii 1 ${subj}_${h}_${Map}
                run wb_command -metric-palette $outwb/$subj.$h.${Map}.native.$Ext.gii MODE_USER_SCALE -pos-user 1 1.7 -neg-user 0 0 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
            done
        fi
    done
fi

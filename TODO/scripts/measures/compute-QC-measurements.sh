 #!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID subjectAlias age [options]
This script computes the different measurements for the dHCP structural pipeline.

Arguments:
  subjectID                     subject ID
  sessionID                     session ID
  subjectAlias                  subject name used for images (e.g. subjectID-sessionID)
  scan_age                      Number: Subject age in weeks. 

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
    echo " failed: see log file logs/$subj-err for details"
    exit 1
  fi
}
################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
subjectID=$1
sessionID=$2
subj=$3
age=$4

datadir=`pwd`
scriptdir=$(dirname "$BASH_SOURCE")

while [ $# -gt 0 ]; do
  case "$5" in
    -d|-data-dir)  shift; datadir=$5; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "QC measurements for the dHCP pipeline
Subject:     $subjectID
Session:     $sessionID 
Subj. Alias: $subj
Age:         $age 
Directory:   $datadir 

$BASH_SOURCE $command
----------------------------"

cd $datadir

log=logs/$subj-measures.log
err=logs/$subj-measures.error
rm -f $log $err

mriqcdir=QC
outdir=$mriqcdir/$subj
mkdir -p $outdir/temp

rage=`printf "%.*f\n" 0 $age`
if [ -f T2/$subj.nii.gz ];then T2ex="True"; else T2ex="False"; fi
if [ -f T1/$subj.nii.gz  ];then T1ex="True"; else T1ex="False"; fi

if [ ! -f $outdir/dhcp-measurements.json ];then 

    # prepare files
    if [ -f restore/T2/${subj}_restore_brain.nii.gz -o -f restore/T1/${subj}_restore_brain.nii.gz ];then
      ln bias/$subj.nii.gz $outdir/temp/bias.nii.gz
      run mirtk padding segmentations/${subj}_tissue_labels.nii.gz segmentations/${subj}_tissue_labels.nii.gz $outdir/temp/tissue_labels.nii.gz 1 0 -1 1 4 0
      #masks
      thr=0
      for t in "bg" csf gm wm;do 
        if [ "$t" == "bg" ];then 
          run fslmaths $outdir/temp/tissue_labels.nii.gz -add 1 -thr 1 -uthr 1 -bin $outdir/temp/${t}_mask.nii.gz
        else
          run fslmaths $outdir/temp/tissue_labels.nii.gz -thr $thr -uthr $thr -bin $outdir/temp/${t}_mask.nii.gz
        fi
        run mirtk erode-image $outdir/temp/${t}_mask.nii.gz $outdir/temp/${t}_mask_open.nii.gz -connectivity 18 > /dev/null 2>&1 
        run mirtk dilate-image $outdir/temp/${t}_mask_open.nii.gz $outdir/temp/${t}_mask_open.nii.gz -connectivity 18 > /dev/null 2>&1 
        let thr=$thr+1
      done
    fi

    # T2 QC measures
    if [ -f restore/T2/${subj}_restore_brain.nii.gz ];then
      run mirtk convert-image restore/T2/${subj}_restore.nii.gz $outdir/temp/T2.nii.gz -rescale 0 1000
      run fslmaths $outdir/temp/T2.nii.gz -mul segmentations/${subj}_brain_mask.nii.gz $outdir/temp/T2_restore_brain.nii.gz
      $scriptdir/image-QC-measurements.sh $outdir/temp T2 $subjectID $sessionID $subj $outdir/T2-qc-measurements.json
    else
      echo "{\"subject_id\":\"$subjectID\", \"session_id\":\"$sessionID\", \"run_id\":\"T2\", \"exists\":\"$T2ex\", \"reorient\":\"\" }" > $outdir/T2-qc-measurements.json
      if [ "$T2ex" == "True" ];then echo "Could not find restore/T2/${subj}_restore_brain.nii.gz!!!";fi
    fi

    # T1 QC measures
    if [ -f restore/T1/${subj}_restore_brain.nii.gz ];then
      run mirtk convert-image restore/T1/${subj}_restore.nii.gz $outdir/temp/T1.nii.gz -rescale 0 1000
      run fslmaths $outdir/temp/T1.nii.gz -mul segmentations/${subj}_brain_mask.nii.gz $outdir/temp/T1_restore_brain.nii.gz
      $scriptdir/image-QC-measurements.sh $outdir/temp T1 $subjectID $sessionID $subj $outdir/T1-qc-measurements.json
    else
      echo "{\"subject_id\":\"$subjectID\", \"session_id\":\"$sessionID\", \"run_id\":\"T1\", \"exists\":\"$T1ex\", \"reorient\":\"\" }" > $outdir/T1-qc-measurements.json
      if [ "$T1ex" == "True" ];then echo "Could not find restore/T1/${subj}_restore_brain.nii.gz!!!";fi
    fi


    # pipeline QC measures
    inputOK="False"
    segOK="False"
    LhemiOK="False"
    RhemiOK="False"
    QCOK='True'
    volume_brain=''
    volume_csf=''
    volume_gm=''
    volume_wm=''
    surface_area=''
    gyrification_index=''
    thickness=''

    if [ -f T2/${subj}.nii.gz ];then 
      inputOK="True"
      if [ -f segmentations/${subj}_all_labels.nii.gz ];then segOK="True";fi
      if [ -f surfaces/$subj/workbench/$subj.L.sphere.native.surf.gii ];then LhemiOK="True"; else QCOK='False';fi
      if [ -f surfaces/$subj/workbench/$subj.R.sphere.native.surf.gii ];then RhemiOK="True"; else QCOK='False';fi

      # additional measures
      volume_brain=`cat measures/$subj/$subj-vol 2>/dev/null`
      volume_csf=`cat measures/$subj/$subj-vol-tissue-regions 2>/dev/null |cut -d' ' -f1`
      volume_gm=`cat measures/$subj/$subj-vol-tissue-regions 2>/dev/null |cut -d' ' -f2`
      volume_wm=`cat measures/$subj/$subj-vol-tissue-regions 2>/dev/null |cut -d' ' -f3`
      surface_area=`cat measures/$subj/$subj-Sa 2>/dev/null`
      gyrification_index=`cat measures/$subj/$subj-GI 2>/dev/null`
      thickness=`cat measures/$subj/$subj-Th 2>/dev/null`
    fi

    agemod=$((rage%2))
    let agegroup=$rage-$agemod
    let nagegroup=$agegroup+2
    if [ $nagegroup -le 28 ];then group="age<$agegroup"
    elif [ $agegroup -ge 44 ];then group="age>=$agegroup"
    else group="$agegroup<=age<$nagegroup"
    fi

    line="{\"subject_id\":\"$subjectID\", \"session_id\":\"$sessionID\", \"run_id\":\"pipeline, $group\", \"age\":\"$age\""
    line="$line, \"inputOK\":\"$inputOK\", \"segOK\":\"$segOK\", \"LhemiOK\":\"$LhemiOK\", \"RhemiOK\":\"$RhemiOK\" "
    for m in volume_brain volume_csf volume_gm volume_wm surface_area gyrification_index thickness;do
      eval "val=\$$m"
      if [ "$val" == "" ];then QCOK='False'; continue;fi
      line="$line, \"$m\":\"$val\""
    done
    line="$line, \"QCOK\":\"$QCOK\" }"
    echo $line > $outdir/dhcp-measurements.json
fi

rm -r $outdir/temp
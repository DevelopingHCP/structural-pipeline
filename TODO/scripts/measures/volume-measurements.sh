#!/bin/bash
subj=$1
outpre=$2
super=""
if [ $# -gt 2 ];then super=$3; fi



super_vol=""
super_all_vol=""
if [ "$super" != "" ];then 
  supstructures=`cat $super|cut -d' ' -f1|sort |uniq`
  for s in ${supstructures};do
    for col in {2..5};do
      substructures=`cat $super | grep "^$s "|cut -d' ' -f $col`
      multipadding segmentations/${subj}_all_labels.nii.gz segmentations/${subj}_all_labels.nii.gz segmentations/${subj}_all_labels.nii.gz-temp.nii.gz `echo $substructures | wc -w` $substructures 0 -invert
      vol[$col]=`fslstats segmentations/${subj}_all_labels.nii.gz-temp.nii.gz -V|cut -d' ' -f2`
    done
    vol[0]=`echo "scale=3; ${vol[2]}+${vol[4]}" | /usr/bin/bc`
    vol[1]=`echo "scale=3; ${vol[3]}+${vol[5]}" | /usr/bin/bc`
    super_vol="$super_vol ${vol[0]} ${vol[1]}"
    super_all_vol="$super_all_vol ${vol[2]} ${vol[3]} ${vol[4]} ${vol[5]}"
  done
  rm segmentations/${subj}_all_labels.nii.gz-temp.nii.gz
fi




vol1=`fslstats segmentations/${subj}_labels.nii.gz -u 49 -V|cut -d' ' -f2`
vol2=`fslstats segmentations/${subj}_all_labels.nii.gz -l 84 -u 86 -V|cut -d' ' -f2`
vol=`echo "$vol1+$vol2"|bc`

echo $vol > $outpre-vol

line=`mirtk measure-volume segmentations/${subj}_tissue_labels.nii.gz |cut -d' ' -f2`
line=`echo $line`; 
echo "$line"  > $outpre-vol-tissue-regions
rline=""; for l in ${line};do rline=$rline`echo "scale=5;$l/$vol"|bc`" ";done
echo $rline > $outpre-rvol-tissue-regions

line=`mirtk measure-volume segmentations/${subj}_labels.nii.gz |cut -d' ' -f2` 
line=`echo $line`"$super_vol"
echo "$line" > $outpre-vol-labels-regions
rline=""; for l in ${line};do rline=$rline`echo "scale=5;$l/$vol"|bc`" ";done
echo $rline > $outpre-rvol-labels-regions

line=`mirtk measure-volume segmentations/${subj}_all_labels.nii.gz |cut -d' ' -f2` 
line=`echo $line`"$super_all_vol"
echo "$line" > $outpre-vol-all-regions
rline=""; for l in ${line};do rline=$rline`echo "scale=5;$l/$vol"|bc`" ";done
echo $rline > $outpre-rvol-all-regions

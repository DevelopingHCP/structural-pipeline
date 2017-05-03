#!/bin/bash

outdir=$1
img=$2
subject=$3
session=$4
subjectAlias=$5
json=$6


for t in "bg" csf gm wm;do 
eval "summary_mean_$t=`fslstats $outdir/${img}.nii.gz -k $outdir/${t}_mask.nii.gz -M`"
eval "summary_stdv_$t=`fslstats $outdir/${img}.nii.gz -k $outdir/${t}_mask.nii.gz -S`"
eval "summary_p05_$t=`fslstats $outdir/${img}.nii.gz -k $outdir/${t}_mask.nii.gz -P 5`"
eval "summary_p95_$t=`fslstats $outdir/${img}.nii.gz -k $outdir/${t}_mask.nii.gz -P 95`"
done

#snr
for t in csf gm wm;do 
fg_mean=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/${t}_mask_open.nii.gz -p 50`
bg_std=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/${t}_mask_open.nii.gz -s`
eval "snr_$t=`echo "$fg_mean / $bg_std "|/usr/bin/bc -l`"
done
fg_mean=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/tissue_labels.nii.gz -p 50`
bg_std=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/tissue_labels.nii.gz -s`
snr=`echo "$fg_mean / $bg_std "|/usr/bin/bc -l`

#cnr
gm_mean=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/gm_mask.nii.gz -m`
wm_mean=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/wm_mask.nii.gz -m`
bg_std=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/bg_mask.nii.gz -s`
cnr=`echo "($gm_mean-$wm_mean)/$bg_std" | /usr/bin/bc -l | sed -e 's:^-::g'`

#dims
dims=`mirtk info $outdir/${img}_restore_brain.nii.gz|grep "Image dime"|cut -d' ' -f4-6`
spacing=`mirtk info $outdir/${img}_restore_brain.nii.gz|grep "Voxel dime"|cut -d' ' -f4-6`
size_x=`echo $dims |cut -d' ' -f1`
size_y=`echo $dims |cut -d' ' -f2`
size_z=`echo $dims |cut -d' ' -f3`
spacing_x=`echo $spacing |cut -d' ' -f1`
spacing_y=`echo $spacing |cut -d' ' -f2`
spacing_z=`echo $spacing |cut -d' ' -f3`

#efc
prod=`echo "$dims" |sed -e 's: :*:g' | /usr/bin/bc -l`
efc_max=`echo "$prod*(1.0/sqrt($prod)) * l(1.0/sqrt($prod))" | /usr/bin/bc -l`
fslmaths $outdir/${img}_restore_brain.nii.gz -sqr $outdir/${img}_sqr.nii.gz
mean_sqr=`fslstats $outdir/${img}_sqr.nii.gz -m`
b_max=`echo "sqrt($mean_sqr*$prod)" | /usr/bin/bc -l`
fslmaths $outdir/${img}_restore_brain.nii.gz -add 1e-16 -div $b_max $outdir/${img}_b_max.nii.gz
fslmaths $outdir/${img}_b_max.nii.gz -log -mul $outdir/${img}_b_max.nii.gz $outdir/${img}_b_max.nii.gz
mean_b_max_img=`fslstats $outdir/${img}_b_max.nii.gz -m`
b_max_img=`echo "$mean_b_max_img*$prod" | /usr/bin/bc -l`
efc=`echo "(1.0 / $efc_max) * $b_max_img" | /usr/bin/bc -l`

#cjv
gm_std=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/gm_mask.nii.gz -s`
wm_std=`fslstats $outdir/${img}_restore_brain.nii.gz -k $outdir/wm_mask.nii.gz -s`
cjv=`echo "($gm_std+$wm_std)  / ($wm_mean - $gm_mean)" | /usr/bin/bc -l`

#inu
cent5=`fslstats $outdir/bias.nii.gz -P 5`
cent95=`fslstats $outdir/bias.nii.gz -P 95`
inu_med=`fslstats $outdir/bias.nii.gz -P 50`
inu_range=`echo "$cent95-$cent5" | /usr/bin/bc -l`


#create json
line="{\"subject_id\":\"$subject\", \"session_id\":\"$session\", \"run_id\":\"${img}\", \"exists\":\"True\", \"reorient\":\"`pwd`/$img/$subjectAlias.nii.gz\" "
for m in cjv cnr efc inu_med inu_range qc_type size_x size_y size_z snr_csf snr_gm snr snr_wm spacing_x spacing_y spacing_z summary_mean_bg summary_mean_csf summary_mean_gm summary_mean_wm summary_p05_bg summary_p05_csf summary_p05_gm summary_p05_wm summary_p95_bg summary_p95_csf summary_p95_gm summary_p95_wm summary_stdv_bg summary_stdv_csf summary_stdv_gm summary_stdv_wm;do
  eval "val=\$$m"
  if [ "$val" == "" ];then continue;fi
  line="$line, \"$m\":\"$val\""
done
line="$line }"
echo $line > $json

#clean up
rm $outdir/${img}_sqr.nii.gz $outdir/${img}_b_max.nii.gz


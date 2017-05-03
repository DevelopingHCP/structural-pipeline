#!/bin/bash
f=$1
hull=$2
outpre=$3
super=""
if [ $# -gt 3 ];then super=$4; fi


if [ -n "$DRAWEMDIR" ]; then
  [ -d "$DRAWEMDIR" ] || { echo "DRAWEMDIR environment variable invalid!" 1>&2; exit 1; }
else
  echo "DRAWEMDIR environment variable not set!" 1>&2; exit 1;
fi


A=`mirtk info $f -area | grep "surface area" |cut -d':' -f2 |tr -d ' '`
# V=`polydatavolume $hull`
V=`mirtk info $hull -area | grep volume | tr -d ' ' | cut -d':' -f2`
T=`perl -e 'use Math::Trig;print ( ( 3*$ARGV[0]/(4*pi) ) ** (1/3))' $V`

corts=`cat $DRAWEMDIR/parameters/cortical.csv`
num_orig_corts=`echo $corts| wc -w`
if [ "$super" != "" ];then 
  supstructures=`cat $super|cut -d' ' -f1|sort |uniq`
  # $s-2 means second column of super structure $s
  for s in ${supstructures};do corts="$corts $s-2 $s-3";done
fi



r=0
for l in 0 ${corts};do

  mask="-mask Labels $l"
  if [ $l == 0 ];then mask="-maskgt Labels 0";fi
  if [ $r -gt $num_orig_corts ];then
    lstr=`echo $l |cut -d'-' -f1`; lh=`echo $l |cut -d'-' -f2`
    substructures=`cat $super | grep "^$lstr " |cut -d' ' -f$lh`
    mask="-mask Labels $substructures"
  fi

  #thickness
  Th=`surface-scalar-statistics $f $mask -name Thickness      |grep "^Median  "|tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  Thl[$r]=$Th

  #sulcation
  Su=`surface-scalar-statistics $f $mask -name SulcalDepth    |grep "^Median  "|tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  Sul[$r]=`echo "scale=5;$Su*$T"|bc`

  #surface area
  Sa=`surface-scalar-statistics $f $mask -name SulcalDepth    |grep "^Area  "  |tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  Sal[$r]=$Sa
  Sarl[$r]=`echo "scale=5;$Sa/$A"|bc`

  #curvature
  Mc=`surface-scalar-statistics $f $mask -name MeanCurvature  |grep "^Median  "|tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  Mcl[$r]=`echo "scale=5;$Mc*$T"|bc`

  #curvature
  Gc=`surface-scalar-statistics $f $mask -name GaussCurvature |grep "^Median  "|tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  Gcl[$r]=`echo "scale=5;$Gc*$T"|bc`

  let r=r+1
done


echo ${Thl[0]} > $outpre-Th
echo ${Thl[*]} | cut -d' ' -f2- > $outpre-Th-regions

echo ${Sul[0]} > $outpre-Su
echo ${Sul[*]} | cut -d' ' -f2- > $outpre-Su-regions

echo ${Sal[0]} > $outpre-Sa
echo ${Sal[*]} | cut -d' ' -f2- > $outpre-Sa-regions
echo ${Sarl[*]} | cut -d' ' -f2- > $outpre-Sar-regions

echo ${Mcl[0]} > $outpre-Mc
echo ${Mcl[*]} | cut -d' ' -f2- > $outpre-Mc-regions
echo ${Gcl[0]} > $outpre-Gc
echo ${Gcl[*]} | cut -d' ' -f2- > $outpre-Gc-regions

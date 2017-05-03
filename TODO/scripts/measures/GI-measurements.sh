#!/bin/bash

pial=$1
outer=$2
outpre=$3
super=""
if [ $# -gt 3 ];then super=$4; fi

if [ -n "$DRAWEMDIR" ]; then
  [ -d "$DRAWEMDIR" ] || { echo "DRAWEMDIR environment variable invalid!" 1>&2; exit 1; }
else
  echo "DRAWEMDIR environment variable not set!" 1>&2; exit 1;
fi


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
  #surface area
  oSa=`surface-scalar-statistics $outer $mask -name Labels |grep "^Area  "|tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  pSa=`surface-scalar-statistics $pial  $mask -name Labels |grep "^Area  "|tr -d ' ' |cut -d':' -f 2 | sed -e 's/[eE]+*/\\*10\\^/'`
  if [ "$oSa" == "" -o "$pSa" == "" ];then 
    GI[$r]="-";
  else
    GI[$r]=`echo "scale=5;$pSa/$oSa" | /usr/bin/bc`
  fi
  let r=r+1
done

echo ${GI[0]} > $outpre-GI
echo ${GI[*]} | cut -d' ' -f2- > $outpre-GI-regions


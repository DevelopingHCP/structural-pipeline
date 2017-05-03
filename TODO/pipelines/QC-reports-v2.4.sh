#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base directory threads
This script connects to the dhcp storage and downloads all the images.

Arguments:
  directory                     The directory used to output the files. 
  threads                       Number of threads
"
  exit;
}

datadir=`pwd`
threads=1
if [ $# -ge 1 ];then datadir=$1; fi
if [ $# -ge 2 ];then threads=$2; fi

scriptdir=$(dirname "$BASH_SOURCE")

mriqcdir=$datadir/QC

# gather info
runqc=0
cat entries.csv entries-failed.csv entries-no-T2.csv | cut -d' ' -f3 | sort | uniq > $mriqcdir/list.csv
for json in dhcp-measurements.json qc-measurements.json;do
  [ ! -f $mriqcdir/$json ] || mv $mriqcdir/$json $mriqcdir/$json.old
  echo "{\"data\":[" > $mriqcdir/$json
  first=1

  while read subj;do
    files=`ls $mriqcdir/$subj/*$json`
    for f in ${files};do 
      line=`cat $f`
      if [ $first -eq 1 ];then first=0; else line=",$line";fi
      echo $line >> $mriqcdir/$json
    done
  done < $mriqcdir/list.csv

  echo "]}" >> $mriqcdir/$json

  if [ -f $mriqcdir/$json.old ];then 
    isdiff=`diff $mriqcdir/$json $mriqcdir/$json.old`
    if [ "$isdiff" != "" ];then runqc=1; fi
  else 
    runqc=1
  fi
done


# plot stuff
if [ $runqc -eq 1 ];then
  # need to fix this earlier
  entry=`cat $mriqcdir/qc-measurements.json |grep -v '"size_x":"[[:digit:]]'|grep -v '"exists":"False"'|grep subject|cut -d'"' -f1-8|sort|uniq`
  if [ "$entry" != "" ];then 
    echo "$entry" >> problems.csv
    cat $mriqcdir/qc-measurements.json | grep -v "$entry" > $mriqcdir/qc-measurements.json.corr
    mv $mriqcdir/qc-measurements.json.corr $mriqcdir/qc-measurements.json
    cat $mriqcdir/dhcp-measurements.json | grep -v "$entry" > $mriqcdir/dhcp-measurements.json.corr
    mv $mriqcdir/dhcp-measurements.json.corr $mriqcdir/dhcp-measurements.json
  fi

  mriqc -o $mriqcdir/reports -w $mriqcdir/work --dhcp-measures $mriqcdir/dhcp-measurements.json --qc-measures $mriqcdir/qc-measurements.json --nthreads $threads
fi


# gather measures
statsdir=$datadir/measures
cat entries.csv | cut -d' ' -f3 | sort | uniq > $statsdir/list-new.csv
runmeas=`diff $statsdir/list.csv $statsdir/list-new.csv`
if [ ! -f $statsdir/list.csv -o "$runmeas" != "" ];then
  measfile=$mriqcdir/reports/pipeline_all_measures.csv
  rm -f $measfile

  # measures
  # vol-labels-regions rvol-labels-regions
  stats="vol vol-tissue-regions rvol-tissue-regions vol-all-regions rvol-all-regions Th Th-regions Su Su-regions Mc Mc-regions Gc Gc-regions GI GI-regions Sa Sa-regions Sar-regions"
  typeset -A name
  name["vol"]="volume"; name["rvol"]="relative volume"; name["Th"]="thickness"; name["Su"]="sulcal depth"; name["Mc"]="mean curvature"; name["Gc"]="Gaussian curvature";  name["GI"]="gyrification index"; name["Sa"]="surface area"; name["Sar"]="relative surface area";

  # header
  lbldir=$scriptdir/../label_names
  header="subject ID, session ID, age at scan"
  for c in ${stats};do
    if [[ $c == *"tissue-regions"* ]];then labels=$lbldir/tissue_labels.csv 
    elif [[ $c == *"labels-regions"* ]];then labels=$lbldir/labels.csv
    elif [[ $c == *"all-regions"* ]];then labels=$lbldir/all_labels.csv
    elif [[ $c == *"regions"* ]];then labels=$lbldir/cortical_labels.csv 
    else labels=""; fi
    cc=`echo $c|cut -d'-' -f1`
    cname=${name[$cc]}
    if [ "$labels" == "" ];then header="$header,$cname";
    else
      while read l;do 
        sname=`echo "$l"|cut -f2|sed -e 's:,::g'`;
        header="$header,$cname - $sname";
      done < $labels
    fi
  done

  # measurements
  echo "$header"> $measfile
  while read subj;do 
    line=`cat entries.csv |grep $subj | cut -d' ' -f1,2,4`
    for c in ${stats};do
      line="$line,"`cat $statsdir/$subj/$subj-$c`
    done
    echo "$line" |sed -e 's: :,:g' >> $measfile
  done < $statsdir/list-new.csv
fi
mv $statsdir/list-new.csv $statsdir/list.csv

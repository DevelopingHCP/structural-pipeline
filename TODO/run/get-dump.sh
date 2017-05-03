#!/bin/bash
#to run this script I need to be connected to dhcpstorage

usage()
{
  base=$(basename "$0")
  echo "usage: $base directory
This script downloads all the images from the dhcp storage.

Arguments:
  dhcp_dir                      The directory used to download the images. 
  directory                     The directory used to output the files. 
"
  exit;
}



[ $# -ge 1 ] || { usage; }

version=$1
dhcpdir=$2
datadir=`pwd`
if [ $# -ge 3 ];then 
    datadir=$3; 
    cd $datadir
    datadir=`pwd`
fi


scriptdir=$(dirname "$BASH_SOURCE")
pipeline=$scriptdir/../pipelines/dhcp-pipeline-$version.sh


subjprefix="sub-"
prefix="$dhcpdir/$subjprefix"
T2suffix="_T2MS_T2MS_Co3DOutSVRMot"
T1suffix="_T1MS_T1MS_Co3DOutSVRMot"


mkdir -p jobs/running jobs/completed jobs/failed
echo "universe     = vanilla
executable   = $pipeline
Notification = ERROR
requirements = Arch == \"X86_64\" && OpSysShortName == \"Ubuntu\" && OpSysMajorVer == 14
request_memory = 8 GB
image_size = 8 GB
getenv = True
" > jobs/head.condor


# DEBUGTEST=3

dirs=`ls -d $dhcpdir/*/ | grep $prefix`
for d in ${dirs};do
  if [ "$DEBUGTEST" != "" ];then let DEBUGTEST=DEBUGTEST-1; if [ $DEBUGTEST -lt 0 ];then break;fi; fi

  subjectID=`echo $d | sed -e "s:$prefix::g" |sed -e 's:\/$::g'`
  sessions=`ls -d $d/*/`
  num=0

  for s in ${sessions};do
    sessionID=`echo $s|sed -e "s:$d/ses-::g" |sed -e 's:\/$::g'`
    subj=$subjectID-$sessionID
    age=`cat $d/$subjprefix${subjectID}_sessions.tsv |grep $sessionID|cut -f3|head -1`

    T2=`ls $s/T2MS/*$T2suffix.nii 2>/dev/null |sed -e 's:\/\/:/:g'`
    T1=`ls $s/T1MS/*$T1suffix.nii 2>/dev/null |sed -e 's:\/\/:/:g'`
    if [ "$T2" == "" ];then T2name="-";else T2name=`basename $T2`;fi
    if [ "$T1" == "" ];then T1name="-";else T1name=`basename $T1`;fi
    entry="$subjectID $sessionID $subj $age $T2name $T1name"

    ex=`cat entries.csv entries-failed.csv entries-no-T2.csv entries-no-age.csv entries-process.csv 2>/dev/null | grep "$entry"`
    if [ "$ex" != "" ];then continue;fi

    agere="^[0-9]+([.][0-9]+)?$"
    if ! [[ $age =~ $agere ]] ; then
      echo "No age for $entry"; 
      echo "$entry" >> entries-no-age.csv
      continue;
    fi
      
    if [ "$T2" == "" ];then 
      echo "No T2 for $entry"; 
      echo "$entry" >> entries-no-T2.csv
      $scriptdir/../scripts/$version/measures/compute-QC-measurements.sh $subjectID $sessionID $subj $age -d $datadir 1>/dev/null 2>/dev/null
      continue;
    fi

    echo "$entry" >> entries-process.csv

    job="$subjectID $sessionID $subj $age -T2 $T2"
    if [ "$T1" != "" ];then 
      job="$job -T1 $T1"  
    fi
    job="$job -d $datadir"  

    # create jobs
    echo '#!/bin/bash' > jobs/$subj.slurm
    echo "$pipeline $job >jobs/$subj.slurm.out 2>jobs/$subj.slurm.err" >> jobs/$subj.slurm

    cp jobs/head.condor jobs/$subj.condor
    echo "output       = jobs/$subj.condor.out" >>jobs/$subj.condor
    echo "error        = jobs/$subj.condor.err" >>jobs/$subj.condor
    echo "" >>jobs/$subj.condor
    echo "arguments=$job" >>jobs/$subj.condor
    echo "Queue" >>jobs/$subj.condor
    echo "" >>jobs/$subj.condor

  done
done
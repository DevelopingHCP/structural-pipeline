#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID scan_age -T2 <subject_T2.nii.gz> [-T1 <subject_T1.nii.gz>] [options]
This script runs the dHCP structural pipeline.

Arguments:
  subjectID                     subject ID
  sessionID                     session ID
  scan_age                      Number: Subject age in weeks. This is used to select the appropriate template for the initial registration. 
                                If the age is <28w or >44w, it will be set to 28w or 44w respectively.
  -T2 <subject_T2.nii.gz>       Nifti Image: The T2 image of the subject (Required)
  -T1 <subject_T1.nii.gz>       Nifti Image: The T1 image of the subject

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}

# log function
run()
{
  echo "$@"
  "$@"
  if [ ! $? -eq 0 ]; then
    echo "failed"
    exit 1
  fi
}

# make run function global
typeset -fx run

# log function for completion
runpipeline()
{
  log=$datadir/logs/$subj.$pipeline.log
  err=$datadir/logs/$subj.$pipeline.err
  echo "running $pipeline pipeline"
  echo "$@"
  "$@" >$log 2>$err
  if [ ! $? -eq 0 ]; then
    echo "failed: see log files $log , $err for details"
    echo "NO" > $datadir/logs/$subj.failed
    exit 1
  fi
  echo "-----------------------"
}


################ Arguments ################

[ $# -ge 3 ] || { usage; }
command=$@
subjectID=$1
sessionID=$2
age=$3

# alias for the specific session
subj=$subjectID-$sessionID
T1="-"
T2="-"
datadir=`pwd`
threads=1
codedir=$(dirname "$BASH_SOURCE")
scriptdir=$codedir/scripts

shift; shift; shift;
while [ $# -gt 0 ]; do
  case "$1" in
    -T2)  shift; T2=$1; ;;
    -T1)  shift; T1=$1; ;;
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;; 
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

################ Checks ################

[ "$T2" != "-" -a "$T2" != "" ] || { echo "T2 image not provided!" >&2; exit 1; }
[ $threads -eq 1 ] || { echo "Warning: Number of threads>1: This may result in minor reproducibility differences"; }

# check whether the different tools are set and load parameters
. ./$codedir/parameters/configuration.sh

################ Run ################

dhcpversion=`git -C "$codedir" branch`
gitversion=`git -C "$codedir" rev-parse HEAD`

echo "dHCP pipeline $dhcpversion (branch version: $gitversion)
Subject:     $subjectID
Session:     $sessionID 
Age:         $age
T1:          $T1
T2:          $T2
Directory:   $datadir 
Threads:     $threads

$BASH_SOURCE $command
----------------------------"

mkdir -p $datadir/logs 

# copy files in the T1/T2 directory
for modality in T1 T2;do 
  mf=${!modality};
  if [ "$mf" == "-" -o "$mf" == "" ]; then continue; fi
  if [ ! -f "$mf" ];  then echo "The $modality image provided as argument does not exist!" >&2; exit 1; fi

  mkdir -p $datadir/$modality
  newf=$datadir/$modality/$subj.nii.gz
  fslreorient2std $mf $newf
  eval "$modality=$newf"
done


if [ ! -f $datadir/logs/$subj.completed -o ! -f $datadir/logs/$subj.failed ];then

  # segmentation
  pipeline=segmentation
  runpipeline $scriptdir/segmentation/pipeline.sh $T2 $age -d $datadir -t $threads

  # generate some additional files
  pipeline=additional
  runpipeline $scriptdir/misc/pipeline.sh $subj $age -d $datadir -t $threads

  # surface extraction
  pipeline=surface
  runpipeline $scriptdir/surface/pipeline.sh $subj -d $datadir -t $threads

  # create data directory for subject
  pipeline=data
  runpipeline $scriptdir/misc/strucure-data.sh $subj $age -d $datadir -t $threads

  # measurements
  # run $scriptdir/measures/pipeline.sh $subjectID $sessionID $subj $age -d $datadir

  echo "OK" > $datadir/logs/$subj.completed
fi
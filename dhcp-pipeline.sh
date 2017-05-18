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
  -T2 <subject_T2.nii.gz>       Nifti Image: The T2 image of the subject
  -T1 <subject_T1.nii.gz>       Nifti Image: The T1 image of the subject (Optional)

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -no-reorient                  The images will not be reoriented before processing (using the FSL fslreorient2std command) (default: False) 
  -h / -help / --help           Print usage.
"
  exit;
}

# log function for completion
runpipeline()
{
  pipeline=$1
  shift
  log=$logdir/$subj.$pipeline.log
  err=$logdir/$subj.$pipeline.err
  echo "running $pipeline pipeline"
  echo "$@"
  "$@" >$log 2>$err
  if [ ! $? -eq 0 ]; then
    echo "Pipeline failed: see log files $log $err for details"
    # echo "NO" > $infodir/$subj.failed
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


roundedAge=`printf "%.*f\n" 0 $age` #round
[ $roundedAge -lt 44 ] || { roundedAge=44; }
[ $roundedAge -gt 28 ] || { roundedAge=28; }

# alias for the specific session
subj=$subjectID-$sessionID
T1="-"
T2="-"
datadir=`pwd`
threads=1
noreorient=0
codedir=$(dirname "$BASH_SOURCE")
scriptdir=$codedir/scripts

shift; shift; shift;
while [ $# -gt 0 ]; do
  case "$1" in
    -T2)  shift; T2=$1; ;;
    -T1)  shift; T1=$1; ;;
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;; 
    -no-reorient) noreorient=1; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

################ Checks ################

[ "$T2" != "-" -a "$T2" != "" ] || { echo "T2 image not provided!" >&2; exit 1; }

# check whether the different tools are set and load parameters
. $codedir/parameters/configuration.sh

################ Run ################

dhcpversion=`git -C "$codedir" branch | grep \* | cut -d ' ' -f2`
gitversion=`git -C "$codedir" rev-parse HEAD`

echo "dHCP pipeline $dhcpversion (branch version: $gitversion)
Subject:     $subjectID
Session:     $sessionID 
Age:         $age
T1:          $T1
T2:          $T2
Directory:   $datadir 
Threads:     $threads"
[ $threads -eq 1 ] || { echo "Warning: Number of threads>1: This may result in minor reproducibility differences"; }
echo "

$BASH_SOURCE $command
----------------------------"

# infodir=$datadir/info 
logdir=$datadir/logs
workdir=$datadir/workdir/$subj
# mkdir -p $infodir
mkdir -p $workdir $logdir

# copy files in the T1/T2 directory
for modality in T1 T2;do 
  mf=${!modality};
  if [ "$mf" == "-" -o "$mf" == "" ]; then continue; fi
  if [ ! -f "$mf" ];  then echo "The $modality image provided as argument does not exist!" >&2; exit 1; fi

  mkdir -p $workdir/$modality
  newf=$workdir/$modality/$subj.nii.gz
  if [ $noreorient -eq 1 ];then
    cp $mf $newf
  else
    fslreorient2std $mf $newf
  fi
  eval "$modality=$newf"
done


# if [ ! -f $infodir/$subj.completed -a ! -f $infodir/$subj.failed ];then

  # segmentation
  runpipeline segmentation $scriptdir/segmentation/pipeline.sh $T2 $subj $roundedAge -d $workdir -t $threads

  # generate some additional files
  runpipeline additional $scriptdir/misc/pipeline.sh $subj $roundedAge -d $workdir -t $threads

  # surface extraction
  runpipeline surface $scriptdir/surface/pipeline.sh $subj -d $workdir -t $threads

  # create data directory for subject
  runpipeline structure-data $scriptdir/misc/structure-data.sh $subjectID $sessionID $subj $roundedAge $datadir $workdir 

  # clean-up
  # runpipeline cleanup rm -r $workdir

  echo "dHCP pipeline completed!"
#   echo "OK" > $infodir/$subj.completed
# fi

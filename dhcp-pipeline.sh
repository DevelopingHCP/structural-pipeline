#!/bin/bash

# fsl prefix ... this was blank for fsl4, but fsl5+ have a versioned command
# prefix
fslprefix=fsl5.0-

usage()
{
  base=$(basename "$0")
  echo "usage: $base <subject_ID> <session_ID> <scan_age> -T2 <subject_T2.nii.gz> [-T1 <subject_T1.nii.gz>] [options]
This script runs the dHCP structural pipeline.

Arguments:
  subject_ID                    subject ID
  session_ID                    session ID
  scan_age                      Number: Subject age in weeks. This is used to select the appropriate template for the initial registration. 
                                If the age is <28w or >44w, it will be set to 28w or 44w respectively.
  -T2 <subject_T2.nii.gz>       Nifti Image: The T2 image of the subject
  -T1 <subject_T1.nii.gz>       Nifti Image: The T1 image of the subject (Optional)

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -additional                   If specified, the pipeline will produce some additional files not included in release v1.0 (such as segmentation prob.maps, warps to MNI space, ..) (default: False) 
  -t / -threads  <number>       Number of threads (CPU cores) used (default: 1)
  -no-reorient                  The images will not be reoriented before processing (using the FSL fslreorient2std command) (default: False) 
  -no-cleanup                   The intermediate files produced (workdir directory) will not be deleted (default: False) 
  -h / -help / --help           Print usage.
"
  exit 1
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
minimal=1
noreorient=0
cleanup=1

shift; shift; shift;
while [ $# -gt 0 ]; do
  case "$1" in
    -T2)  shift; T2=$1; ;;
    -T1)  shift; T1=$1; ;;
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;;
    -additional)  minimal=0; ;;
    -no-reorient) noreorient=1; ;;
    -no-cleanup) cleanup=0; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

################ Checks ################

[ "$T2" != "-" -a "$T2" != "" ] || { echo "T2 image not provided!" >&2; exit 1; }

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/parameters/configuration.sh

scriptdir=$codedir/scripts

roundedAge=`printf "%.*f\n" 0 $age` #round
[ $roundedAge -lt $template_max_age ] || { roundedAge=$template_max_age; }
[ $roundedAge -gt $template_min_age ] || { roundedAge=$template_min_age; }

################ Run ################
version=`cat $codedir/version`
echo "dHCP pipeline $version
Subject:     $subjectID
Session:     $sessionID 
Age:         $age
T1:          $T1
T2:          $T2
Directory:   $datadir 
Threads:     $threads
Minimal:     $minimal"
[ $threads -eq 1 ] || { echo "Warning: Number of threads>1: This may result in minor reproducibility differences"; }
echo "

$BASH_SOURCE $command
----------------------------"

last_file=$datadir/derivatives/sub-$subjectID/ses-$sessionID/anat/Native/sub-${subjectID}_ses-${sessionID}_wb.spec
if [ -f $last_file ];then echo "dHCP pipeline already completed!";exit; fi


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
    ${fslprefix}fslreorient2std $mf $newf
  fi
  eval "$modality=$newf"
done


# segmentation
runpipeline segmentation $scriptdir/segmentation/pipeline.sh $T2 $subj $roundedAge -d $workdir -t $threads

# generate some additional files
runpipeline additional $scriptdir/misc/pipeline.sh $subj $roundedAge -d $workdir -t $threads

# surface extraction
runpipeline surface $scriptdir/surface/pipeline.sh $subj -d $workdir -t $threads

# create data directory for subject
runpipeline structure-data $scriptdir/misc/structure-data.sh $subjectID $sessionID $subj $roundedAge $datadir $workdir $minimal

# clean-up
if [ $cleanup -eq 1 ];then
  runpipeline cleanup rm -r $workdir
fi

echo "dHCP pipeline completed!"

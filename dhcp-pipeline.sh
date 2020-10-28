#!/bin/bash

# if FSLDIR is not defined, assume we need to read the FSL startup
if [ -z ${FSLDIR+x} ]; then
  if [ -f /etc/fsl/fsl.sh ]; then
    . /etc/fsl/fsl.sh
  else
    echo FSLDIR is not set and there is no system-wide FSL startup
    exit 1
  fi

fi

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
  -template <atlasname>         Template used for common space of subjects, options: `echo $AVAILABLE_TEMPLATES|sed -e 's: :, :g'` (default: `echo $AVAILABLE_TEMPLATES|cut -d ' ' -f1`)
  -a / -atlas  <atlasname>      Atlas used for the segmentation, options: `echo $AVAILABLE_ATLASES|sed -e 's: :, :g'` (default: `echo $AVAILABLE_ATLASES|cut -d ' ' -f1`)
  -ta / -tissue-atlas  <atlasname>  Atlas used to compute the GM tissue probability, options: `echo $AVAILABLE_TISSUE_ATLASES|sed -e 's: :, :g'` (default: `echo $AVAILABLE_TISSUE_ATLASES|cut -d ' ' -f1`)
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -additional                   If specified, the pipeline will produce some additional files not included in release v1.0 (such as segmentation prob.maps, warps to MNI space, ..) (default: False) 
  -t / -threads  <number>       Number of threads (CPU cores) used (default: 1)
  -no-reorient                  The images will not be reoriented before processing (using the FSL fslreorient2std command) (default: False) 
  -recon-from-seg               Surface reconstruction using only the segmentation, no image edge information
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


################ Configuration ################

# initial configuration
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/parameters/configuration.sh

################ Arguments ################

[ $# -ge 3 ] || { usage; }
command=$@
subjectID=$1
sessionID=$2
age=$3
shift; shift; shift;

# alias for the specific session
subj=$subjectID-$sessionID
T1="-"
T2="-"
datadir=`pwd`
threads=1
minimal=1
noreorient=0
recon_from_seg=0
cleanup=1
template=`echo $AVAILABLE_TEMPLATES|cut -d ' ' -f1`
atlas=`echo $AVAILABLE_ATLASES|cut -d ' ' -f1`
tissue_atlas=`echo $AVAILABLE_TISSUE_ATLASES|cut -d ' ' -f1`

while [ $# -gt 0 ]; do
  case "$1" in
    -T2)  shift; T2=$1; ;;
    -T1)  shift; T1=$1; ;;
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;;
    -template)  shift; template=$1; ;; 
    -a|-atlas)  shift; atlas=$1; ;;
    -ta|-tissue-atlas)  shift; tissue_atlas=$1; ;;
    -additional)  minimal=0; ;;
    -no-reorient) noreorient=1; ;;
    -recon-from-seg) recon_from_seg=1 ;;
    -no-cleanup) cleanup=0; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

# consider the case where the user is running us inside docker with an
# argument like:
#
#	-T2 data/T1w.nii.gz
#
# the user's data directory will be mapped to /data, and that's out WORKDIR,
# so we need to remove the leading data/ component for the path to be valid
#
# we don't want to make this change unless we have to, so only drop the first
# pathname component if the file named by T2 does not exist and	T2 is a 
# relative path

if [[ "$T2" != /* && ! -f "$T2" ]]; then
  T1=${T1#*/}
  T2=${T2#*/}
fi


################ Checks ################

# template configuration
template_exists=`echo " $AVAILABLE_TEMPLATES "|grep " $template "`
if [ "$template_exists" == "" ];then
  echo "Unknown template: $template" >&2;
  exit;
fi
. $codedir/parameters/$template/configuration.sh

# atlas configuration
. $DRAWEMDIR/parameters/set_atlas.sh $tissue_atlas $atlas

[ "$T2" != "-" -a "$T2" != "" ] || { echo "T2 image not provided!" >&2; exit 1; }

scriptdir=$codedir/scripts

rounded_age=`printf "%.*f\n" 0 $age` #round
template_age=$rounded_age
[ $template_age -lt $TEMPLATE_MAX_AGE ] || { template_age=$TEMPLATE_MAX_AGE; }
[ $template_age -gt $TEMPLATE_MIN_AGE ] || { template_age=$TEMPLATE_MIN_AGE; }

if [ $recon_from_seg -eq 0 ];then
  reconstruction="segmentation + image"
  recon_from_seg_arg=""
else
  reconstruction="segmentation"
  recon_from_seg_arg="-recon-from-seg";
fi

################ Run ################
version=`cat $codedir/version`
echo "dHCP pipeline $version
Subject:        $subjectID
Session:        $sessionID
Age:            $age
T1:             $T1
T2:             $T2
Tissue atlas:   $tissue_atlas
Atlas:          $atlas
Template:       $template
Surface Recon:  $reconstruction
Directory:      $datadir
Threads:        $threads
Minimal:        $minimal"
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
    fslreorient2std $mf $newf
  fi
  eval "$modality=$newf"
done


# segmentation
runpipeline segmentation $scriptdir/segmentation/pipeline.sh $T2 $subj $rounded_age -d $workdir -ta $tissue_atlas -a $atlas -t $threads

# generate some additional files
runpipeline additional $scriptdir/misc/pipeline.sh $subj $template_age -d $workdir -t $threads

# surface extraction
runpipeline surface $scriptdir/surface/pipeline.sh $subj $recon_from_seg_arg -d $workdir -t $threads

# create data directory for subject
runpipeline structure-data $scriptdir/misc/structure-data.sh $subjectID $sessionID $subj $template_age $datadir $workdir $minimal

# clean-up
if [ $cleanup -eq 1 ];then
  runpipeline cleanup rm -r $workdir
fi

echo "dHCP pipeline completed!"

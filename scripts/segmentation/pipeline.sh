#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base T2 subject age [options]
This script runs the dHCP surface pipeline.

Arguments:
  T2                            T2 volume to segment
  subject                       Subject ID

Options:
  -a / -atlas  <atlasname>      Atlas used for the segmentation, options: `echo $AVAILABLE_ATLASES|sed -e 's: :, :g'` (default: `echo $AVAILABLE_ATLASES|cut -d ' ' -f1`)
  -ta / -tissue-atlas  <atlasname>  Atlas used to compute the GM tissue probability, options: `echo $AVAILABLE_TISSUE_ATLASES|sed -e 's: :, :g'` (default: `echo $AVAILABLE_TISSUE_ATLASES|cut -d ' ' -f1`)
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}


################ ARGUMENTS ################

[ $# -ge 3 ] || { usage; }
command=$@
T2=$1
subj=$2
age=$3

datadir=`pwd`
atlas=`echo $AVAILABLE_ATLASES|cut -d ' ' -f1`
tissue_atlas=`echo $AVAILABLE_TISSUE_ATLASES|cut -d ' ' -f1`
threads=1

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/../../parameters/configuration.sh

shift; shift; shift
while [ $# -gt 0 ]; do
  case "$1" in
    -d|-data-dir)  shift; datadir=$1; ;;
    -a|-atlas)  shift; atlas=$1; ;;
    -ta|-tissue-atlas)  shift; tissue_atlas=$1; ;;
    -t|-threads)  shift; threads=$1; ;; 
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "dHCP Segmentation pipeline
T2:           $T2 
Subject:      $subj 
Age:          $age
Tissue atlas: $tissue_atlas
Atlas:        $atlas
Directory:    $datadir 
Threads:      $threads

$BASH_SOURCE $command
----------------------------"


################ PIPELINE ################

cd $datadir

if [ ! -f segmentations/${subj}_all_labels.nii.gz ];then
  # run Draw-EM
  run mirtk neonatal-segmentation $T2 $age -t $threads -c 1 -p 1 -v 1 -ta $tissue_atlas -a $atlas
  echo "----------------------------
"
fi

# Note:
# The segmentation generates the following files which are used by the dHCP pipeline:
# $subj_tissue_labels.nii.gz  : tissue labels
# $subj_all_labels.nii.gz     : all labels
# $subj_labels.nii.gz         : similar to all labels file, where labels that span across GM/WM are merged
# $subj_L_white.nii.gz        : left hemisphere white mask for surface reconstruction
# $subj_R_white.nii.gz        : right hemisphere white mask for surface reconstruction
# $subj_L_pial.nii.gz         : left hemisphere pial mask for surface reconstruction
# $subj_R_pial.nii.gz         : left hemisphere pial mask for surface reconstruction
# $subj_brain_mask.nii.gz     : mask generated with BET
# posteriors/*/$subj.nii.gz   : posteriors of the different structures (where * the different structure directory)

mkdir -p masks 
# mask based on the tissue seg
if [ ! -f masks/$subj.nii.gz ];then 
    run mirtk padding segmentations/${subj}_tissue_labels.nii.gz segmentations/${subj}_tissue_labels.nii.gz masks/$subj-labels.nii.gz 2 $CSF_TISSUE_LABEL $BG_TISSUE_LABEL 0
    run fslmaths masks/$subj-labels.nii.gz -bin -dilD -dilD -dilD -ero -ero masks/$subj-dil.nii.gz
    run mirtk fill-holes masks/$subj-dil.nii.gz masks/$subj.nii.gz
    rm masks/$subj-labels.nii.gz masks/$subj-dil.nii.gz 
fi

# mask based on BET
if [ ! -f masks/$subj-bet.nii.gz ];then 
  ln segmentations/${subj}_brain_mask.nii.gz masks/$subj-bet.nii.gz
fi



 #!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID subjectAlias age [options]
This script computes the different measurements for the dHCP structural pipeline.

Arguments:
  subjectID                     subject ID
  sessionID                     session ID
  subjectAlias                  subject name used for images (e.g. subjectID-sessionID)
  scan_age                      Number: Subject age in weeks. 

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
subjectID=$1
sessionID=$2
subj=$3
age=$4

datadir=`pwd`
scriptdir=$(dirname "$BASH_SOURCE")

while [ $# -gt 0 ]; do
  case "$5" in
    -d|-data-dir)  shift; datadir=$5; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "Measurements for the dHCP pipeline
Subject:     $subjectID
Session:     $sessionID 
Subj. Alias: $subj
Age:         $age 
Directory:   $datadir 

$BASH_SOURCE $command
----------------------------"

################ PIPELINE ################

echo "computing volume and surface measures..."
$scriptdir/compute-measurements.sh $subj -d $datadir 

echo "----------------------------
"
echo "computing QC measures..."
$scriptdir/compute-QC-measurements.sh $subjectID $sessionID $subj $age -d $datadir 
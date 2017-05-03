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

run()
{
  echo "$@"
  "$@"
  if [ $? -eq 0 ]; then
    echo " done"
  else
    echo " failed"
    exit 1
  fi
}


datadir=`pwd`
threads=1
if [ $# -ge 1 ];then 
    datadir=$1; 
    cd $datadir
    datadir=`pwd`
fi
if [ $# -ge 2 ];then threads=$2; fi

scriptdir=$(dirname "$BASH_SOURCE")



# results dir
version="v2.4"
recon=ReconstructionsRelease03
dhcpdir=/vol/dhcp-reconstructed-images/UpdatedReconstructions/$recon
resultsdir=/vol/dhcp-derived-data/derived_$version/${recon}_derived_${version}

# condor or slurm
runon=slurm


if [ -f entries-process.csv ];then
  ################# UPLOAD #################
  # upload
  run $scriptdir/upload.sh $resultsdir

  # update the entries
  for status in completed failed;do
    if [ ! -f entries-process-$status.csv ];then continue; fi
    while read line;do
        subj=`echo $line | cut -d' ' -f3`
        mv jobs/running/$subj.condor jobs/$status

        if [ "$status" == "completed" ];then 
          echo "$line" >> entries.csv
        else
          echo "$line" >> entries-failed.csv
        fi
        
        cat entries-process.csv | grep -v "$line" > entries-process.csv.tmp
        mv entries-process.csv.tmp entries-process.csv
    done < entries-process-$status.csv
    rm -f entries-process-$status.csv
  done

  num=`cat entries-process.csv |wc -l`
  if [ $num -eq 0 ];then rm entries-process.csv; fi

  # upload fails
  rm -f $resultsdir/failed.csv
  cat entries-failed.csv |cut -d' ' -f3 | sort | uniq > $resultsdir/failed.csv




  ################# QC #################

  # merge QC
  run $scriptdir/../pipelines/QC-reports-$version.sh $datadir $threads

  # upload QC
  rm -rf $resultsdir/QC/reports-temp $resultsdir/QC/anatomical_group*.pdf
  mkdir -p $resultsdir/QC
  cp -R QC/reports $resultsdir/QC/reports-temp
  rm -rf $resultsdir/QC/reports
  mv $resultsdir/QC/reports-temp $resultsdir/QC/reports
  ln -s $resultsdir/QC/reports/anatomical_group.pdf $resultsdir/QC/anatomical_group.pdf
  ln -s $resultsdir/QC/reports/anatomical_group_stats.pdf $resultsdir/QC/anatomical_group_stats.pdf
  setfacl -R -m "u:www-data:r-x"  $resultsdir/QC
fi


################# NEW DATA #################

# get files, prepare jobs
run $scriptdir/get-dump.sh $version $dhcpdir

# run jobs
while read line;do
    subj=`echo $line | cut -d' ' -f3`
    if [ "$runon" == "slurm" ];then
      if [ -f jobs/$subj.slurm ];then 
          mv  jobs/$subj.slurm jobs/running
          run ssh -t predict5 "cd `pwd`;sbatch --mem=12G -n 1 -o jobs/$subj.slurm.out -e jobs/$subj.slurm.err jobs/running/$subj.slurm"
      fi
    else
      if [ -f jobs/$subj.condor ];then 
          mv  jobs/$subj.condor jobs/running
          run condor_submit jobs/running/$subj.condor
      fi
    fi
done < entries-process.csv
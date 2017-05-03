#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base results_dir data_dir
This script uploads all the results.

Arguments:
  results_dir             The directory used to upload the files. 
  data_dir                The directory used to output the files. 
"
  exit;
}

linkfile()
{
    new_name=$1
    link_name=$2
    new_name_base=`basename $new_name`
    ln -s $new_name_base $link_name
}

addfile()
{
    orig_file=$1
    new_name=$2
    link_name=$3
    cp $datadir/$orig_file $new_name
    linkfile $new_name $link_name
}


[ $# -ge 1 ] || { usage; }

resultsdir=$1
datadir=`pwd`
if [ $# -ge 2 ];then 
    datadir=$2; 
    cd $datadir
    datadir=`pwd`
fi

mni=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz

rm -f entries-process-completed.csv entries-process-failed.csv
while read line;do
    subj=`echo $line | cut -d' ' -f3`

    # pipeline completed?
    if [ -f $datadir/logs/$subj.failed ];then 
        echo "$line" >> entries-process-failed.csv
        continue;
    fi  
    if [ ! -f $datadir/logs/$subj.completed ];then continue;fi  

    subjectID=`echo $line | cut -d' ' -f1`
    sessionID=`echo $line | cut -d' ' -f2`
    age=`echo $line | cut -d' ' -f4`  
    age=`printf "%.*f\n" 0 $age` #round
    [ $age -lt 44 ] || { age=44; }
    [ $age -gt 28 ] || { age=28; }
    T2name=`echo $line | cut -d' ' -f5 | sed -e 's:.nii$::g' | sed -e 's:.nii.gz$::g'`
    T1name=`echo $line | cut -d' ' -f6 | sed -e 's:.nii$::g' | sed -e 's:.nii.gz$::g'`

    subjdir=sub-$subjectID
    sessiondir=ses-$sessionID
    outputdir=$resultsdir/$subjdir/$sessiondir/structural/Native
    segdir=$outputdir/segmentations
    surfdir=$outputdir/surfaces
    dofdir=$outputdir/dofs
    biasdir=$outputdir/bias
    maskdir=$outputdir/masks
    T1dir=$outputdir/T1
    T2dir=$outputdir/T2
    mkdir -p $outputdir


    # images
    mkdir -p $T2dir
    for restore in "" "_defaced" "_restore" "_restore_defaced" "_restore_brain" "_restore_bet";do
        addfile restore/T2/${subj}${restore}.nii.gz $T2dir/${T2name}${restore}.nii.gz $T2dir/T2w${restore}.nii.gz
    done

    if [ "$T1name" != "-" ];then 
        mkdir -p $T1dir
        for restore in "" "_defaced" "_restore" "_restore_defaced" "_restore_brain" "_restore_bet";do
            addfile restore/T1/${subj}${restore}.nii.gz $T1dir/${T1name}${restore}.nii.gz $T1dir/T1w${restore}.nii.gz
        done
    fi

    # masks
    mkdir -p $maskdir
    addfile masks/$subj.nii.gz $maskdir/${T2name}_brain.nii.gz $maskdir/brain.nii.gz
    addfile masks/$subj-bet.nii.gz $maskdir/${T2name}_bet.nii.gz $maskdir/bet.nii.gz    

    # segmentations
    mkdir -p $segdir
    for seg in labels all_labels tissue_labels;do
        addfile segmentations/${subj}_${seg}.nii.gz $segdir/${T2name}_${seg}.nii.gz $segdir/$seg.nii.gz
    done
    
    # dofs
    mkdir -p $dofdir
    addfile dofs/${subj}-template-$age-n.dof.gz $dofdir/${T2name}-template-$age-n.dof.gz $dofdir/template-$age-n.dof.gz
    addfile dofs/${subj}-template-$age-r.dof.gz $dofdir/${T2name}-template-$age-r.dof.gz $dofdir/template-$age-r.dof.gz
    addfile dofs/${subj}-MNI-n.dof.gz $dofdir/${T2name}-MNI-n.dof.gz $dofdir/MNI-n.dof.gz
    if [ "$T1name" != "-" ];then 
        addfile dofs/${subj}-T2-T1-r.dof.gz $dofdir/${T2name}-T2-T1-r.dof.gz $dofdir/T2-T1-r.dof.gz
    fi

    # warps
    mirtk convert-dof dofs/$subj-template-$age-n.dof.gz $dofdir/${T2name}-template-$age-n.nii.gz -input-format mirtk -output-format fsl -target restore/T2/${subj}${restore}.nii.gz -source $DRAWEMDIR/atlases/non-rigid-v2/T2/template-$age.nii.gz
    mirtk convert-dof dofs/$subj-template-$age-r.dof.gz $dofdir/${T2name}-template-$age-r.mat -input-format mirtk -output-format fsl -target restore/T2/${subj}${restore}.nii.gz -source $DRAWEMDIR/atlases/non-rigid-v2/T2/template-$age.nii.gz
    mirtk convert-dof dofs/$subj-MNI-n.dof.gz $dofdir/${T2name}-MNI-n.nii.gz -input-format mirtk -output-format fsl -target restore/T2/${subj}${restore}.nii.gz -source $mni
    linkfile $dofdir/${T2name}-template-$age-n.nii.gz $dofdir/template-$age-n.nii.gz
    linkfile $dofdir/${T2name}-template-$age-r.mat $dofdir/template-$age-r.mat
    linkfile $dofdir/${T2name}-MNI-n.nii.gz $dofdir/MNI-n.nii.gz
    if [ "$T1name" != "-" ];then 
        mirtk convert-dof dofs/$subj-T2-T1-r.dof.gz $dofdir/${T2name}-T2-T1-r.mat -input-format mirtk -output-format fsl -target T2/$subj.nii.gz -source T1/$subj.nii.gz
        linkfile $dofdir/${T2name}-T2-T1-r.mat $dofdir/T2-T1-r.mat
    fi

    # bias
    mkdir -p $biasdir
    addfile bias/$subj.nii.gz $biasdir/${T2name}_bias.nii.gz $biasdir/bias.nii.gz
    
    # surfaces
    for meshdir in vtk workbench;do
        mkdir -p $surfdir-$meshdir
        sfiles=`ls surfaces/$subj/$meshdir`
        for sf in ${sfiles};do
            so=`echo $sf|sed -e "s:$subj:$T2name:g"`
            sho=`echo $sf|sed -e "s:$subj.::g"`
            isspec=`echo $sf|grep ".spec"`

            if [ "$isspec" != "" ];then
                # for spec files
                cat surfaces/$subj/$meshdir/$sf |sed -e "s:$subj:$T2name:g" > $surfdir-$meshdir/$so
                cat surfaces/$subj/$meshdir/$sf |sed -e "s:$subj.::g" > $surfdir-$meshdir/$sho
            else 
                addfile surfaces/$subj/$meshdir/$sf $surfdir-$meshdir/$so $surfdir-$meshdir/$sho
            fi
        done
    done

    # to update the entries
    echo "$line" >> entries-process-completed.csv
done < entries-process.csv


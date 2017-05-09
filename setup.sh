#!/bin/bash

usage(){
    echo "usage"
    exit 1
}

build_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/build
num_cores=6

packages="WORKBENCH VTK MIRTK SPHERICALMESH"
vars="install git branch hash folder build cmake_flags"

WORKBENCH_install=1
WORKBENCH_git=git@github.com:Washington-University/workbench.git
WORKBENCH_branch=master
WORKBENCH_hash=019ba364bf1b4f42793d43427848e3c77154c173
WORKBENCH_folder=$build_dir/WORKBENCH
WORKBENCH_build=$WORKBENCH_folder/build

VTK_install=1
VTK_git=git@github.com:Kitware/VTK.git
VTK_branch=release
# VTK_hash=b86da7eef93f75c4a7f524b3644523ae6b651bc4
VTK_hash=v7.0.0
VTK_folder=$build_dir/VTK
VTK_build=$VTK_folder/build

MIRTK_install=1
MIRTK_git=git@github.com:BioMedIA/MIRTK.git
MIRTK_branch=master
MIRTK_hash=a30957a5bb3ff24fc789ebd3841f9dd2f870992e
MIRTK_folder=$build_dir/MIRTK
MIRTK_build=$MIRTK_folder/build
MIRTK_cmake_flags="-DMODULE_Deformable=ON -DMODULE_DrawEM=ON -DWITH_VTK=ON -DDEPENDS_VTK_DIR=$VTK_build -DWITH_TBB=ON"

SPHERICALMESH_install=1
SPHERICALMESH_git=git@gitlab.doc.ic.ac.uk:am411/SphericalMesh.git
SPHERICALMESH_branch=dhcp
SPHERICALMESH_hash=826897dfc4ff7d74c503d5a22de3ea9fea9c332e
SPHERICALMESH_folder=$build_dir/SphericalMesh
SPHERICALMESH_build=$SPHERICALMESH_folder/build
SPHERICALMESH_cmake_flags="-DMIRTK_DIR=$MIRTK_build -DVTK_DIR=$VTK_build"

while [ $# -gt 0 ]; do
  case "$1" in
    -*_DIR=*)  
          param=`echo $1|sed -e 's:^-::g'`;
          pkg=`echo $param|cut -d'=' -f1|sed -e 's:_DIR::g'`
          val=`echo $param|cut -d'_' -f2`
          ok=0
          for p in ${packages};do
            if [ "$p" == "$pkg" ];then let ok++; break; fi
          done
          if [ ! $ok -eq 1 ];then usage;fi
          eval ${pkg}_install=0
          eval ${pkg}_build=$val
          ;;
    -D)   
          shift;
          param=$1; 
          flag=`echo $param|cut -d'=' -f1`
          pkg=`echo $flag|cut -d'_' -f1`
          var=`echo $flag|cut -d'_' -f2-`
          ok=0
          for p in ${packages};do
            if [ "$p" == "$pkg" ];then let ok++; break; fi
          done
          for v in ${vars};do
            if [ "$v" == "$var" ];then let ok++; break; fi
          done
          if [ ! $ok -eq 2 ];then usage;fi
          echo "setting $param"; 
          eval "$param";;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
    *) break ;;
  esac
  shift
done

echo ""
echo mkdir -p $build_dir

for package in ${packages};do 
    for var in ${vars};do 
        eval "package_$var=\${${package}_${var}}"
    done

    if [ ! $package_install -eq 1 ];then continue;fi

    echo "Downloading $package"
    echo "git clone --recursive -b $package_branch $package_git $package_folder
    cd $package_folder
    git reset --hard $package_hash
    mkdir $package_build
    cd $package_build
    cmake $package_folder $package_cmake_flags
    make -j$num_cores
    cd $build_dir
    "
done
#!/bin/bash

usage(){
    echo "usage"
    exit 1
}

run(){
  echo "$@"
  "$@"
  if [ ! $? -eq 0 ]; then
    echo "$@ : command failed"
    exit 1
  fi
}

set_if_undef(){
    arg=$1
    name=`echo $arg|cut -d'=' -f1`
    val=`echo $arg|cut -d'=' -f2-`
    if [[ ! -v $name ]];then
        eval "$name=\$val"
    fi
}

code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
num_cores=6

packages="WORKBENCH VTK MIRTK SPHERICALMESH"
vars="install git branch version folder build cmake_flags make_flags"

while [ $# -gt 0 ]; do
  case "$1" in
    -j)
          shift;
          num_cores=$1 ;;
    -build)
          shift;
          build_dir=$1 ;;
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
          eval ${pkg}_build=$val ;;
    -D*=*)   
          param=`echo $1|sed -e 's:^-D::g'`;
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




set_if_undef build_dir=$code_dir/build

set_if_undef WORKBENCH_install=1
set_if_undef WORKBENCH_git=git@github.com:Washington-University/workbench.git
set_if_undef WORKBENCH_branch=master
set_if_undef WORKBENCH_version=019ba364bf1b4f42793d43427848e3c77154c173
set_if_undef WORKBENCH_folder="$build_dir/workbench"
set_if_undef WORKBENCH_build="$build_dir/workbench/build"
set_if_undef WORKBENCH_cmake_flags="-DCMAKE_CXX_FLAGS=-std=c++11 $WORKBENCH_folder/src"
set_if_undef WORKBENCH_make_flags="wb_command"

set_if_undef VTK_install=1
set_if_undef VTK_git=git@github.com:Kitware/VTK.git
set_if_undef VTK_branch=release
set_if_undef VTK_version=v7.0.0
set_if_undef VTK_folder="$build_dir/VTK"
set_if_undef VTK_build="$build_dir/VTK/build"

set_if_undef MIRTK_install=1
set_if_undef MIRTK_git=git@github.com:BioMedIA/MIRTK.git
set_if_undef MIRTK_branch=master
set_if_undef MIRTK_version=a30957a5bb3ff24fc789ebd3841f9dd2f870992e
set_if_undef MIRTK_folder="$build_dir/MIRTK"
set_if_undef MIRTK_build="$build_dir/MIRTK/build"
set_if_undef MIRTK_cmake_flags="-DMODULE_Deformable=ON -DMODULE_DrawEM=ON -DWITH_VTK=ON -DDEPENDS_VTK_DIR=$VTK_build -DWITH_TBB=ON"

set_if_undef SPHERICALMESH_install=1
set_if_undef SPHERICALMESH_git=git@gitlab.doc.ic.ac.uk:am411/SphericalMesh.git
set_if_undef SPHERICALMESH_branch=dhcp
set_if_undef SPHERICALMESH_version=826897dfc4ff7d74c503d5a22de3ea9fea9c332e
set_if_undef SPHERICALMESH_folder="$build_dir/SphericalMesh"
set_if_undef SPHERICALMESH_build="$build_dir/SphericalMesh/build"
set_if_undef SPHERICALMESH_cmake_flags="-DMIRTK_DIR=$MIRTK_build/lib/cmake/mirtk -DVTK_DIR=$VTK_build"

set_if_undef cmake_flags="-DMIRTK_DIR=$MIRTK_build/lib/cmake/mirtk -DVTK_DIR=$VTK_build"


run mkdir -p $build_dir

for package in ${packages};do 
    for var in ${vars};do 
        eval "package_$var=\${${package}_${var}}"
    done

    if [ ! $package_install -eq 1 ];then continue;fi

    echo "Downloading $package"
    [ -d $package_folder ] || run git clone --recursive -b $package_branch $package_git $package_folder
    run cd $package_folder
    run git reset --hard $package_version
    run mkdir -p $package_build
    run cd $package_build
    run cmake $package_folder $package_cmake_flags
    run make -j$num_cores $package_make_flags
    
done

cmake_flags=`eval echo $cmake_flags`

run cd $build_dir
run cmake $code_dir $cmake_flags
run make -j$num_cores

#!/bin/bash


echo_red(){
    echo -e '\033[0;31m'"$@"'\033[0m'
}
echo_green(){
    echo -e '\033[0;32m'"$@"'\033[0m'
}
echo_blue(){
    echo -e '\033[0;34m'"$@"'\033[0m'
}

usage(){
    echo "usage"
    exit 1
}

run(){
  echo_blue $@
  if [ $verbose -eq 0 ];then 
    "$@" >> $logfile
  else
    "$@"
  fi
  if [ ! $? -eq 0 ]; then
    echo_red "$@ : command failed"
    if [ $verbose -eq 0 ];then 
        echo_red "see log file: $logfile"; 
    fi
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

full_path_dir(){
    echo "$( cd $1 && pwd )"
}

# check if commands  exist
download=wget
if ! hash $download 2>/dev/null; then
    download=curl
    if ! hash $download 2>/dev/null; then
        echo_red "wget or curl need to be installed!"
        exit 1
    fi
fi
if ! hash unzip 2>/dev/null; then
    echo_red "unzip need to be installed!"
    exit 1
fi

code_dir=`full_path_dir $( dirname ${BASH_SOURCE[0]} )`
num_cores=1
verbose=0
logfile=$code_dir/setup.log
rm -f $logfile

packages="WORKBENCH ITK VTK MIRTK SPHERICALMESH"
vars="install git branch version folder build cmake_flags make_flags"

while [ $# -gt 0 ]; do
  case "$1" in
    -v)   shift;
          verbose=$1 ;;
    -j)
          shift;
          num_cores=$1 ;;
    -build)
          shift;
          pipeline_build=$1;;
    -*_DIR=*)  
          param=`echo $1|sed -e 's:^-::g'`;
          pkg=`echo $param|cut -d'=' -f1|sed -e 's:_DIR::g'`
          val=`echo $param|cut -d'=' -f2`
          ok=0
          for p in ${packages};do
            if [ "$p" == "$pkg" ];then let ok++; break; fi
          done
          if [ ! $ok -eq 1 ];then usage;fi
          val=`full_path_dir $val`
          eval ${pkg}_install=0
          eval ${pkg}_build=$val ;;
    -D*=*)   
          param=`echo $1|sed -e 's:^-D::g'`;
          name=`echo $param|cut -d'=' -f1`
          pkg=`echo $name|cut -d'_' -f1`
          var=`echo $name|cut -d'_' -f2-`
          val=`echo $param|cut -d'=' -f2-`
          ok=0
          for p in ${packages};do
            if [ "$p" == "$pkg" ];then let ok++; break; fi
          done
          for v in ${vars};do
            if [ "$v" == "$var" ];then let ok++; break; fi
          done
          if [ "$v" == "build" -o "$v" == "folder" ];then
            val=`full_path_dir $val`
          fi
          if [ ! $ok -eq 2 ];then usage;fi
          echo "setting $name=$val"; 
          eval "$name=$val";;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
    *) break ;;
  esac
  shift
done


set_if_undef pipeline_build=$code_dir/build
mkdir -p $pipeline_build
pipeline_build=`full_path_dir $pipeline_build`


set_if_undef WORKBENCH_install=1
set_if_undef WORKBENCH_git=https://github.com/Washington-University/workbench.git
set_if_undef WORKBENCH_branch=master
set_if_undef WORKBENCH_version=019ba364bf1b4f42793d43427848e3c77154c173
set_if_undef WORKBENCH_folder="$pipeline_build/workbench"
set_if_undef WORKBENCH_build="$pipeline_build/workbench/build"
set_if_undef WORKBENCH_cmake_flags="-DCMAKE_CXX_FLAGS=-std=c++11 $WORKBENCH_folder/src"
set_if_undef WORKBENCH_make_flags="wb_command"

set_if_undef ITK_install=1
set_if_undef ITK_git=https://github.com/InsightSoftwareConsortium/ITK.git
set_if_undef ITK_branch=master
set_if_undef ITK_version=v4.11.1
set_if_undef ITK_folder="$pipeline_build/ITK"
set_if_undef ITK_build="$pipeline_build/ITK/build"
set_if_undef ITK_cmake_flags="-DBUILD_EXAMPLES=OFF"

set_if_undef VTK_install=1
set_if_undef VTK_git=https://github.com/Kitware/VTK.git
set_if_undef VTK_branch=release
set_if_undef VTK_version=v7.0.0
set_if_undef VTK_folder="$pipeline_build/VTK"
set_if_undef VTK_build="$pipeline_build/VTK/build"

set_if_undef MIRTK_install=1
set_if_undef MIRTK_git=https://github.com/BioMedIA/MIRTK.git
set_if_undef MIRTK_branch=master
set_if_undef MIRTK_version=88c8266b016b465551d0bbafca9aed6340fdc1fb
set_if_undef MIRTK_folder="$pipeline_build/MIRTK"
set_if_undef MIRTK_build="$pipeline_build/MIRTK/build"
set_if_undef MIRTK_cmake_flags="-DMODULE_Deformable=ON -DMODULE_DrawEM=ON -DDEPENDS_Eigen3_DIR=$code_dir/ThirdParty/eigen-eigen-67e894c6cd8f -DWITH_VTK=ON -DDEPENDS_VTK_DIR=$VTK_build -DWITH_TBB=ON"

set_if_undef SPHERICALMESH_install=1
set_if_undef SPHERICALMESH_git=https://gitlab.doc.ic.ac.uk/am411/SphericalMesh.git
set_if_undef SPHERICALMESH_branch=dhcp
set_if_undef SPHERICALMESH_version=826897dfc4ff7d74c503d5a22de3ea9fea9c332e
set_if_undef SPHERICALMESH_folder="$pipeline_build/SphericalMesh"
set_if_undef SPHERICALMESH_build="$pipeline_build/SphericalMesh/build"
set_if_undef SPHERICALMESH_cmake_flags="-DMIRTK_DIR=$MIRTK_build/lib/cmake/mirtk -DVTK_DIR=$VTK_build"


set_if_undef cmake_flags="-DMIRTK_DIR=$MIRTK_build/lib/cmake/mirtk -DVTK_DIR=$VTK_build -DITK_DIR=$ITK_build"
DRAWEMDIR=$MIRTK_folder/Packages/DrawEM

for package in ${packages};do 
    for var in ${vars};do 
        eval "package_$var=\${${package}_${var}}"
    done

    if [ ! $package_install -eq 1 ];then continue;fi

    echo_green "Installing $package"
    [ -d $package_folder ] || run git clone --recursive -b $package_branch $package_git $package_folder
    run cd $package_folder
    run git reset --hard $package_version
    run git submodule update

    # install specific version of DrawEM
    if [ "$package" == "MIRTK" ];then 
        cd $DRAWEMDIR
        # git reset --hard 411f44be1a032c3835ae3db02e8c732532e28c3c
        git pull origin dhcp
        cd $package_folder
    fi

    run mkdir -p $package_build
    run cd $package_build
    run cmake $package_folder $package_cmake_flags
    run make -j$num_cores $package_make_flags
    
done

cmake_flags=`eval echo $cmake_flags`

run cd $pipeline_build
run cmake $code_dir $cmake_flags
run make -j$num_cores



if [ ! -d $code_dir/atlases ];then 
    echo_green "Downloading atlases"
    run $download "https://www.doc.ic.ac.uk/%7Eam411/atlases-dhcp-structural-pipeline-v1.zip"
    run unzip $code_dir/atlases-dhcp-structural-pipeline-v1.zip -d $code_dir
    run rm $code_dir/atlases.zip
fi
if [ ! -d $DRAWEMDIR/atlases ];then 
    run ln -s $code_dir/atlases $DRAWEMDIR/atlases
fi



echo_green "Setting up environment"
for package in WORKBENCH MIRTK SPHERICALMESH pipeline;do 
    eval "bin=\${${package}_build}/bin"
    pathext="$pathext$bin:"
done
rm -f $code_dir/parameters/path.sh
echo "export DRAWEMDIR=$DRAWEMDIR" >> $code_dir/parameters/path.sh
echo "export PATH=$pathext"'${PATH}' >> $code_dir/parameters/path.sh
chmod +x $code_dir/parameters/path.sh

# replace Draw-EM N4 pre-built binary with the built one from this setup
rm $DRAWEMDIR/ThirdParty/ITK/N4
ln -s $pipeline_build/bin/N4 $DRAWEMDIR/ThirdParty/ITK/N4


echo_green "Setup completed successfully!"
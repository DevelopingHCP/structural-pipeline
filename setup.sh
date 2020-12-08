#!/bin/bash

packages="WORKBENCH ITK VTK MIRTK SPHERICALMESH"
vars="dir install git branch version folder build cmake_flags make_flags"


usage()
{
  base=$(basename "$0")
  echo "usage: $base [options]
Setup of the dHCP structural pipeline.

Options:
  -j <number>                   Number of CPU cores to be used for the setup (default: 1)
  -build <directory>            The directory used to setup the pipeline (default: build)
  -D<package>_<var>=<value>     This allows to change the default setup values for the packages.
                                The <package> can vary between: $packages
                                The <var> can vary between: $vars
                                where: 
                                    <package>_dir         : use the pre-built directory specified by <value>, instead of downloading and building it
                                    <package>_install     : whether to install (<value>=1) or not (<value>=0) the package (default <value>=1)
                                    <package>_git         : use the git repository for the package specified by <value>
                                    <package>_branch      : use the git branch for the package specified by <value>
                                    <package>_version     : use the git commit/tag for the package specified by <value>
                                    <package>_folder      : use the directory specified by <value> to run the cmake (must contain a CMakeLists.txt)
                                    <package>_build       : use the directory specified by <value> to build the package
                                    <package>_cmake_flags : use the flags specified by <value> to cmake the package
                                    <package>_make_flags  : use the flags specified by <value> to make the package
  -h / -help / --help           Print usage.
"
  exit;
}



# echo with color, prints in the terminal and the log file
echo_color(){
  msg='\033[0;'"$@"'\033[0m'
  echo -e $msg >> $logfile
  echo -e $msg 
}
echo_red(){
  echo_color '31m'"$@"
}
echo_green(){
  echo_color '32m'"$@"
}
echo_blue(){
  echo_color '34m'"$@"
}

exit_error(){
  echo_red "$@"
  exit 1
}

# run the command
run(){
  echo_blue "$@"
  eval $@ >> $logfile 2>> $logfile
  if [ ! $? -eq 0 ]; then
    exit_error "$@ : command failed, see log file: $logfile"
  fi
}

# set the variable if it is undefined
set_if_undef(){
    arg=$1
    name=`echo $arg|cut -d'=' -f1`
    val=`echo $arg|cut -d'=' -f2-`
    if [ -z ${!name} ];then
        eval "$name=\$val"
    fi
}

# get the full path of the directory
full_path_dir(){
    echo "$( cd $1 && pwd )"
}

# check if commands exist
download=wget
download_option="-O"
if ! hash $download 2>/dev/null; then
    download=curl
    download_option="-o"
    if ! hash $download 2>/dev/null; then
        exit_error "wget or curl need to be installed! "
    fi
fi
for comm in unzip cmake git;do
    if ! hash $comm 2>/dev/null; then
        exit_error "$comm needs to be installed! "
    fi
done
# check if g++-5/gcc-5 exist or if g++/gcc are of version 5
compiler_version_required=7
cxx_compiler=g++
c_compiler=gcc
for compiler in cxx_compiler c_compiler;do
  compiler_bin=${!compiler}
  compiler_bin_version=${compiler_bin}-${compiler_version_required}
  if hash $compiler_bin_version 2>/dev/null; then eval "$compiler=$compiler_bin_version"; continue;fi
  if hash $compiler_bin 2>/dev/null; then 
    compiler_version=`$compiler_bin -dumpversion|cut -d'.' -f1`
    if [ $compiler_version -eq $compiler_version_required ];then continue; fi
  fi
  exit_error "$compiler_bin version $compiler_version_required needs to be installed! "
done

# arguments
code_dir=`full_path_dir $( dirname ${BASH_SOURCE[0]} )`
num_cores=1
logfile=$code_dir/setup.log
rm -f $logfile

while [ $# -gt 0 ]; do
  case "$1" in
    -j)
          shift;
          num_cores=$1 ;;
    -build)
          shift;
          pipeline_build=$1;;
    -D*=*)   
          param=`echo $1|sed -e 's:^-D::g'`;
          name=`echo $param|cut -d'=' -f1`
          pkg=`echo $name|cut -d'_' -f1| awk '{print toupper($0)}'`
          var=`echo $name|cut -d'_' -f2-| awk '{print tolower($0)}'`
          val=`echo $param|cut -d'=' -f2-`
          ok=0
          for p in ${packages};do
            if [ "$p" == "$pkg" ];then let ok++; break; fi
          done
          if [ ! $ok -eq 1 ];then usage;fi
          if [ "$var" == "dir" ];then
              val=`full_path_dir $val`
              comm="${pkg}_install=0; ${pkg}_build=$val"
          else
              if [ "$var" == "build" -o "$var" == "folder" ];then
                mkdir -p $val
                val=`full_path_dir $val`
              else
                  ok=0
                  for v in ${vars};do
                    if [ "$v" == "$var" ];then let ok++; break; fi
                  done
                if [ ! $ok -eq 1 ];then usage;fi
              fi
              comm="$name=$val"
          fi 
          echo_green "setting $comm"; 
          eval "$comm"
          ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
    *) break ;;
  esac
  shift
done


set_if_undef pipeline_build=$code_dir/build
mkdir -p $pipeline_build
pipeline_build=`full_path_dir $pipeline_build`
pipelinebinaries_build=$pipeline_build/pipeline/build


cxx_flags="-DCMAKE_CXX_COMPILER=`which $cxx_compiler` -DCMAKE_C_COMPILER=`which $c_compiler`"

set_if_undef WORKBENCH_install=1
set_if_undef WORKBENCH_git=https://github.com/Washington-University/workbench.git
set_if_undef WORKBENCH_branch=master
set_if_undef WORKBENCH_version=v1.4.2
set_if_undef WORKBENCH_folder="$pipeline_build/workbench"
set_if_undef WORKBENCH_build="$pipeline_build/workbench/build"
set_if_undef WORKBENCH_cmake_flags="-DCMAKE_BUILD_TYPE=Release -DWORKBENCH_USE_QT5=TRUE $WORKBENCH_folder/src"
set_if_undef WORKBENCH_make_flags="wb_view wb_command"

set_if_undef ITK_install=1
set_if_undef ITK_git=https://github.com/InsightSoftwareConsortium/ITK.git
set_if_undef ITK_branch=master
set_if_undef ITK_version=v5.1.1
set_if_undef ITK_folder="$pipeline_build/ITK"
set_if_undef ITK_build="$pipeline_build/ITK/build"
set_if_undef ITK_cmake_flags="-DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF"

set_if_undef VTK_install=1
set_if_undef VTK_git=https://github.com/Kitware/VTK.git
set_if_undef VTK_branch=release
set_if_undef VTK_version=v9.0.1
set_if_undef VTK_folder="$pipeline_build/VTK"
set_if_undef VTK_build="$pipeline_build/VTK/build"

set_if_undef MIRTK_install=1
set_if_undef MIRTK_git=https://github.com/BioMedIA/MIRTK.git
set_if_undef MIRTK_branch=master
set_if_undef MIRTK_version=77d3f391b49b0cee9e80da774fb074995fdf415f
set_if_undef MIRTK_folder="$pipeline_build/MIRTK"
set_if_undef MIRTK_build="$pipeline_build/MIRTK/build"
set_if_undef MIRTK_cmake_flags="-DMODULE_Deformable=ON -DMODULE_DrawEM=ON -DDEPENDS_Eigen3_DIR=$code_dir/ThirdParty/eigen-eigen-67e894c6cd8f -DWITH_VTK=ON -DDEPENDS_VTK_DIR=$VTK_build -DWITH_ITK=ON -DITK_DIR=$ITK_build -DWITH_TBB=ON"

set_if_undef DRAWEM_version=feature/fetal_segmentation

set_if_undef SPHERICALMESH_install=1
set_if_undef SPHERICALMESH_git=https://github.com/amakropoulos/SphericalMesh.git
set_if_undef SPHERICALMESH_branch=dhcp-v1.2
set_if_undef SPHERICALMESH_version=16dc94e264215cc936f6908635f53418fcccc5af
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

    if [ $package == "MIRTK" ]; then
      ( cd Packages/DrawEM \
        && run echo checking out drawem \
        && git checkout $DRAWEM_version )
    fi

    run mkdir -p $package_build
    run cd $package_build
    run cmake $package_folder $package_cmake_flags $cxx_flags
    run make -j$num_cores $package_make_flags
    
done

echo_green "Installing pipeline"
cmake_flags=`eval echo $cmake_flags`
run mkdir -p $pipelinebinaries_build
run cd $pipelinebinaries_build
run cmake $code_dir $cmake_flags $cxx_flags
run make -j$num_cores



echo_green "Setting up environment"
wb_command=`find $WORKBENCH_build -name wb_command`
wb_view=`find $WORKBENCH_build -name wb_view`
pathext=`dirname $wb_command`:`dirname $wb_view`:
for package in MIRTK SPHERICALMESH pipelinebinaries;do 
    eval "bin=\${${package}_build}/bin"
    pathext="$pathext:$bin"
done
rm -f $code_dir/parameters/path.sh
echo "export DRAWEMDIR=$DRAWEMDIR" >> $code_dir/parameters/path.sh
echo "export PATH=$pathext:"'${PATH}' >> $code_dir/parameters/path.sh
chmod +x $code_dir/parameters/path.sh


echo_green "Setup completed successfully! "

#!/bin/bash
# Copyright 2021 Huawei Technologies Co., Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROGRAM=$(basename "$0")
CMAKE_BOOL=(OFF ON)

# ==============================================================================
# Default values

build_type='Release'
cmake_debug_mode=0
cmake_make_silent=0
cmake_generator='Unix Makefiles'
configure_only=0
do_clean=0
do_clean_build_dir=0
do_clean_cache=0
do_clean_venv=0
do_configure=0
dry_run=0
enable_cxx=0
enable_gpu=0
enable_projectq=1
enable_quest=0
force_local_pkgs=0
local_pkgs=()
n_jobs=-1

if command -v nproc >/dev/null 2>&1; then
    n_jobs_default=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
    n_jobs_default=$(sysctl -n hw.logicalcpu)
else
    n_jobs_default=8
fi

source_dir=$(realpath "$BASEPATH")
build_dir="$source_dir/build"
python_venv_path=$source_dir/venv

third_party_libraries=$(cd "$BASEPATH/third_party" \
                            && find . -maxdepth 1 -type d ! -path . | grep -vE '(cmake|CMakeLists.txt)' \
                                | sed 's|./||')

# ==============================================================================

call_cmd() {
   if [ $dry_run -ne 1 ]; then
       "$@"
   else
       echo "$@"
   fi
 }

# ------------------------------------------------------------------------------

call_cmake() {
    if [ $dry_run -ne 1 ]; then
        echo "**********"
        echo "Calling CMake with: cmake " "$@"
        echo "**********"
    fi
    call_cmd "$CMAKE" "$@"
}

# ==============================================================================

function join_by {
    local d=${1-} f=${2-}
    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}

# ==============================================================================

function version_less_equal() {
    local a_major a_minor b_major b_minor
    a_major=$(echo "$1" | cut -d. -f1)
    a_minor=$(echo "$1" | cut -d. -f2)
    b_major=$(echo "$2" | cut -d. -f1)
    b_minor=$(echo "$2" | cut -d. -f2)

    if [ "$a_major" -le "$b_major" ]; then
        if [ "$a_minor" -le "$b_minor" ]; then
            return 0
        fi
    fi
    return 1
}

# ==============================================================================

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
no_arg() {
    if [ -n "$OPTARG" ]; then die "No arg allowed for --$OPT option"; fi; }
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

# ------------------------------------------------------------------------------

print_show_libraries() {
    echo 'Known third-party libraries:'
    for lib in $third_party_libraries; do
        echo " - $lib"
    done
}

parse_with_libraries() {
    if ! echo "$third_party_libraries" | tr ' ' '\n' | grep -F -x -q "$1" ; then
        print_show_libraries
        echo ''
        die "Unknown library for --with-$1 or --without-$1"
    fi

    if [ "$1" == "projectq" ]; then
        enable_projectq=$2
    elif [ "$1" == "quest" ]; then
        enable_quest=$2
    elif [ "$2" -eq 1 ]; then
        local_pkgs+=("$1")
    else
        for index in "${!local_pkgs[@]}" ; do [[ ${local_pkgs[$index]} == "$1" ]] && unset -v 'local_pkgs[$index]' ; done
        local_pkgs=("${local_pkgs[@]}")
    fi
}

# ------------------------------------------------------------------------------

help_message() {
    echo 'Build MindQunantum locally (in-source build)'
    echo ''
    echo 'This is mainly relevant for developers that do not want to always '
    echo 'have to reinstall the Python package'
    echo ''
    echo 'This script will create a Python virtualenv in the MindQuantum root'
    echo 'directory and then build all the C++ Python modules and place the'
    echo 'generated libraries in their right locations within the MindQuantum'
    echo 'folder hierarchy so Python knows how to find them.'
    echo ''
    echo 'A pth-file will be created in the virtualenv site-packages directory'
    echo 'so that the MindQuantum root folder will be added to the Python PATH'
    echo 'without the need to modify PYTHONPATH.'
    echo -e '\nUsage:'
    echo "  $PROGRAM [options] [-- cmake_options]"
    echo -e '\nOptions:'
    echo '  -h,--help            Show this help message and exit'
    echo '  -n                   Dry run; only print commands but do not execute them'
    echo ''
    echo '  -B,--build [dir]     Specify build directory'
    echo "                       Defaults to: $build_dir"
    echo '  --clean              Run make clean before building'
    echo '  --clean-all          Clean everything before building.'
    echo '                       Equivalent to --clean-venv --clean-builddir'
    echo '  --clean-builddir     Delete build directory before building'
    echo '  --clean-cache        Re-run CMake with a clean CMake cache'
    echo '  --clean-venv         Delete Python virtualenv before building'
    echo '  -c,--configure       Force running the CMake configure step'
    echo '  --configure-only     Stop after the CMake configure and generation steps (ie. before building MindQuantum)'
    echo '  --cxx                (experimental) Enable MindQuantum C++ support'
    echo '  --debug              Build in debug mode'
    echo '  --debug-cmake        Enable debugging mode for CMake configuration step'
    echo '  --gpu                Enable GPU support'
    echo '  -j,--jobs [N]        Number of parallel jobs for building'
    echo "                       Defaults to: $n_jobs_default"
    echo '  --local-pkgs         Compile third-party dependencies locally'
    echo '  --ninja              Build using Ninja instead of make'
    echo '  --quiet              Disable verbose build rules'
    echo '  --show-libraries     Show all known third-party libraries'
    echo '  --venv [dir]         Path to Python virtual environment'
    echo "                       Defaults to: $python_venv_path"
    echo '  --with-<library>     Build the third-party <library> from source'
    echo '                       (ignored if --local-pkgs is passed, except for projectq and quest)'
    echo '  --without-<library>  Do not build the third-party library from source'
    echo '                       (ignored if --local-pkgs is passed, except for projectq and quest)'
    echo ''
    echo 'Any options after "--" will be passed onto CMake during the configuration step'
    echo -e '\nExample calls:'
    echo "$PROGRAM -B build"
    echo "$PROGRAM -B build --gpu"
    echo "$PROGRAM -B build --cxx --with-boost --without-quest --venv=/tmp/venv"
    echo "$PROGRAM -B build -- -DCMAKE_CUDA_COMPILER=/opt/cuda/bin/nvcc"
}

# ==============================================================================

while getopts hcnB:j:-: OPT; do
    # shellcheck disable=SC2214,SC2295
    if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
        OPT="${OPTARG%%=*}"       # extract long option name
        OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
        OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    if [[ $OPT =~ with-([a-zA-Z0-9_]+) ]]; then
        OPT=with
        enable_lib=1
        library=${BASH_REMATCH[1]}
    elif [[ $OPT =~ without-([a-zA-Z0-9_]+) ]]; then
        OPT=with
        enable_lib=0
        library=${BASH_REMATCH[1]}
    fi
    case "$OPT" in
        h | help )       no_arg;
                         help_message >&2
                         exit 1 ;;
        B | build)       needs_arg;
                         build_dir="$OPTARG"
                         ;;
        clean )          no_arg;
                         do_clean=1
                         ;;
        clean-all )      no_arg;
                         do_clean_venv=1
                         do_clean_build_dir=1
                         ;;
        clean-builddir ) no_arg;
                         do_clean_build_dir=1
                         ;;
        clean-cache )    no_arg;
                         do_clean_cache=1
                         ;;
        clean-venv )     no_arg;
                         do_clean_venv=1
                         ;;
        c | configure )  no_arg;
                         do_configure=1
                         ;;
        configure-only ) no_arg;
                         configure_only=1
                         ;;
        cxx )            no_arg;
                         enable_cxx=1
                         ;;
        debug )          no_arg;
                         build_type='Debug'
                         ;;
        debug-cmake )    no_arg;
                         cmake_debug_mode=1
                         ;;
        gpu )            no_arg;
                         enable_gpu=1
                         ;;
        j | jobs )       needs_arg;
                         n_jobs="$OPTARG"
                         ;;
        local-pkgs )     no_arg;
                         force_local_pkgs=1
                         ;;
        n )              no_arg;
                         dry_run=1
                         ;;
        ninja )          no_arg;
                         cmake_generator='Ninja'
                         ;;
        quiet )          no_arg;
                         cmake_make_silent=1
                         ;;
        show-libraries ) no_arg;
                         print_show_libraries
                         exit 1
                         ;;
        venv )           needs_arg;
                         python_venv_path="$OPTARG"
                         ;;
        with )           no_arg;
                         parse_with_libraries "$library" $enable_lib
                         ;;
        ??* )           die "Illegal option --OPT: $OPT" ;;
        \? )            exit 2 ;;  # bad short option (error reported via getopts)
    esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

# ==============================================================================
# Locate python or python3

if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON=python
else
    echo 'Unable to locate python or python3!' 1>&2
    exit 1
fi

# ==============================================================================

set -e

cd "${BASEPATH}"

# ------------------------------------------------------------------------------
# Create a virtual environment for building the wheel

if [ $do_clean_venv -eq 1 ]; then
    echo "Deleting virtualenv folder: $python_venv_path"
    call_cmd rm -rf "$python_venv_path"
fi

if [ $do_clean_build_dir -eq 1 ]; then
    echo "Deleting build folder: $build_dir"
    call_cmd rm -rf "$build_dir"
fi

created_venv=0
if [ ! -d "$python_venv_path" ]; then
    created_venv=1
    echo "Creating Python virtualenv: $PYTHON -m venv $python_venv_path"
    call_cmd $PYTHON -m venv "$python_venv_path"
fi

call_cmd source "$python_venv_path/bin/activate"

# ------------------------------------------------------------------------------
# Locate cmake or cmake3

has_cmake=0

if [ -f "$python_venv_path/bin/cmake" ]; then
    CMAKE="$python_venv_path/bin/cmake"
    has_cmake=1
fi

cmake_version_min=$(grep -oP 'cmake_minimum_required\(VERSION\s+\K[0-9\.]+' "$BASEPATH/CMakeLists.txt")

if [ $has_cmake -ne 1 ]; then
    if command -v cmake > /dev/null 2>&1; then
        CMAKE=cmake
    elif command -v cmake3 > /dev/null 2>&1; then
        CMAKE=cmake3
    fi

    if [[ -n "$CMAKE" ]]; then
        cmake_version=$("$CMAKE" --version | head -1 | cut -d' ' -f3)

        if version_less_equal "$cmake_version_min" "$cmake_version"; then
            has_cmake=1
        fi
    fi
fi

if [ $has_cmake -eq 0 ]; then
    echo "Installing CMake inside the Python virtual environment"
    call_cmd $PYTHON -m pip install -U "cmake>=$cmake_version_min"
    CMAKE="$python_venv_path/bin/cmake"
fi

# ------------------------------------------------------------------------------

if [ $created_venv -eq 1 ]; then
    pkgs=(pip setuptools wheel build pybind11)

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        pkgs+=(auditwheel)
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        pkgs+=(delocate)
    fi

    echo "Updating Python packages: $PYTHON -m pip install -U ${pkgs[*]}"
    call_cmd $PYTHON -m pip install -U "${pkgs[@]}"
fi

if [ $dry_run -ne 1 ]; then
    # Make sure the root directory is in the virtualenv PATH
    site_pkg_dir=$($PYTHON -c 'import site; print(site.getsitepackages()[0])')
    pth_file="$site_pkg_dir/mindquantum_local.pth"

    if [ ! -e "$pth_file" ]; then
        echo "Creating pth-file in $pth_file"
        echo "$BASEPATH" > "$pth_file"
    fi
fi

# ------------------------------------------------------------------------------
# Setup arguments for build

cmake_args=(-DIN_PLACE_BUILD:BOOL=ON
            -DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON
            -DENABLE_PROJECTQ:BOOL="${CMAKE_BOOL[$enable_projectq]}"
            -DENABLE_QUEST:BOOL="${CMAKE_BOOL[$enable_quest]}"
            -G "${cmake_generator}")

if [[ $cmake_debug_mode -eq 1 ]]; then
    cmake_args+=(-DENABLE_CMAKE_DEBUG:BOOL=ON)
fi

if [[ $cmake_make_silent -eq 1 ]]; then
    cmake_args+=(-DUSE_VERBOSE_MAKEFILE:BOOL=OFF)
fi

if [[ $enable_cxx -eq 1 ]]; then
    cmake_args+=(-DENABLE_CXX_EXPERIMENTAL:BOOL=ON)
fi

if [[ $enable_gpu -eq 1 ]]; then
    cmake_args+=(-DENABLE_CUDA:BOOL=ON)
fi

local_pkgs_str=$(join_by , "${local_pkgs[@]}")
if [[ $force_local_pkgs -eq 1 ]]; then
    cmake_args+=(-DMQ_FORCE_LOCAL_PKGS=all)
elif [ -n "$local_pkgs_str" ]; then
    cmake_args+=(-DMQ_FORCE_LOCAL_PKGS="$local_pkgs_str")
fi

if [[ $n_jobs -eq -1 && ! $cmake_generator == "Ninja"  ]]; then
    n_jobs=$n_jobs_default
fi

if [ $n_jobs -ne -1 ]; then
    cmake_args+=(-DJOBS:STRING="$n_jobs")
fi

# ------------------------------------------------------------------------------
# Build

if [[ ! -d "$build_dir" || $do_clean_build_dir -eq 1 ]]; then
    do_configure=1
elif [ $do_clean_cache -eq 1 ]; then
    do_configure=1
    echo "Removing CMake cache at: $build_dir/CMakeCache.txt"
    call_cmd rm -f "$build_dir/CMakeCache.txt"
    echo "Removing CMake files at: $build_dir/CMakeFiles"
    call_cmd  rm -rf "$build_dir/CMakeFiles"
fi

if [ $do_configure -eq 1 ]; then
    call_cmake -S "$source_dir" -B "$build_dir" "${cmake_args[@]}" "$@"
fi

if [ $configure_only -eq 1 ]; then
    exit 0
fi

if [ $do_clean -eq 1 ]; then
    call_cmake --build "$build_dir" --target clean
fi

call_cmake --build "$build_dir" --target all -j "$n_jobs" --config "$build_type"

# ==============================================================================

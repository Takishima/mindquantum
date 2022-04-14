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

Param(
    # Flags
    [switch]$Clean,
    [switch]$CleanAll,
    [switch]$CleanBuildDir,
    [switch]$CleanCache,
    [switch]$CleanVenv,
    [switch]$Configure,
    [switch]$ConfigureOnly,
    [switch]$Cxx,
    [switch]$Debug,
    [switch]$DebugCMake,
    [switch]$DryRun,
    [switch]$Doc,
    [switch]$Docs,
    [switch]$Gpu,
    [switch]$Help,
    [switch]$Ninja,
    [switch]$Quiet,
    [switch]$ShowLibraries,
    [switch]$UpdateVenv,
    [switch]$c,
    [switch]$h,
    [switch]$n,

    # Integer options
    [ValidateRange("Positive")][int]$J,
    [ValidateRange("Positive")][int]$Jobs,

    # String options
    [ValidateNotNullOrEmpty()][string]$B,
    [ValidateNotNullOrEmpty()][string]$Build,
    [ValidateNotNullOrEmpty()][string]$CudaArch,
    [ValidateNotNullOrEmpty()][string]$Venv,

    # CMake arguments
    [ValidateNotNullOrEmpty()][string]$G,
    [ValidateNotNullOrEmpty()][string]$A
)

$BASENAME = Split-Path $MyInvocation.MyCommand.Path -Leaf
$BASEPATH = Split-Path $MyInvocation.MyCommand.Path -Parent
$CMAKE_BOOL = @('OFF', 'ON')

$IsLinuxEnv = (Get-Variable -Name "IsLinux" -ErrorAction Ignore)
$IsMacOSEnv = (Get-Variable -Name "IsMacOS" -ErrorAction Ignore)
$IsWinEnv = !$IsLinuxEnv -and !$IsMacOSEnv

# ==============================================================================
# Default values

$build_type = "Release"
$cmake_debug_mode = 0
$cmake_make_silent = 0
$configure_only = 0
$cuda_arch=""
$do_clean = 0
$do_clean_build_dir = 0
$do_clean_cache = 0
$do_clean_venv = 0
$do_docs = 0
$do_configure = 0
$do_update_venv = 0
$dry_run = 0
$enable_cxx = 0
$enable_gpu = 0
$enable_projectq = 1
$enable_quest = 0
$force_local_pkgs = 0
$local_pkgs = @()
$n_jobs = -1

$source_dir = Resolve-Path $BASEPATH
$build_dir = "$BASEPATH\build"
$python_venv_path="$source_dir\venv"


$third_party_libraries = ((Get-ChildItem -Path $BASEPATH\third_party -Directory -Exclude cmake).Name).ForEach("ToLower")

# ==============================================================================

function Call-Cmd {
    if ($dry_run -ne 1) {
        Invoke-Expression -Command "$args"
    }
    else {
        Write-Output "$args"
    }
}

function Call-CMake {
    if ($dry_run -ne 1) {
        Write-Output "**********"
        Write-Output "Calling CMake with: cmake $args"
        Write-Output "**********"
    }
    Call-Cmd $CMAKE @args
}

function Test-CommandExists{
    Param ($command)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'

    try {
        if(Get-Command $command) {
            return $TRUE
        }
        else {
            return $FALSE
        }
    }
    Catch {
        return $FALSE
    }
    Finally {
        $ErrorActionPreference=$oldPreference
    }
}

# ==============================================================================

$n_jobs_default = 8
if(Test-CommandExists nproc) {
    $n_jobs_default = nproc
}
elseif (Test-CommandExists sysctl) {
    $n_jobs_default = Invoke-Expression -Command "sysctl -n hw.logicalcpu"
}
elseif ($IsWinEnv -eq 1) {
    if (Test-CommandExists Get-CimInstance) {
        $n_jobs_default = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    }
    elseif (Test-CommandExists wmic) {
        $tmp = (wmic cpu get NumberOfLogicalProcessors /value) -Join ' '
        if ($tmp -match "\s*[a-zA-Z]+=([0-9]+)") {
            $n_jobs_default = $Matches[1]
        }
    }
}

# ==============================================================================

function print_show_libraries {
    Write-Output 'Known third-party libraries:'
    foreach($lib in $third_party_libraries) {
        Write-Output (" - {0}" -f $lib)
    }
}

# ------------------------------------------------------------------------------

function help_message() {
    Write-Output 'Build MindQunantum locally (in-source build)'
    Write-Output ''
    Write-Output 'This is mainly relevant for developers that do not want to always '
    Write-Output 'have to reinstall the Python package'
    Write-Output ''
    Write-Output 'This script will create a Python virtualenv in the MindQuantum root'
    Write-Output 'directory and then build all the C++ Python modules and place the'
    Write-Output 'generated libraries in their right locations within the MindQuantum'
    Write-Output 'folder hierarchy so Python knows how to find them.'
    Write-Output ''
    Write-Output 'A pth-file will be created in the virtualenv site-packages directory'
    Write-Output 'so that the MindQuantum root folder will be added to the Python PATH'
    Write-Output 'without the need to modify PYTHONPATH.'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output ('  {0} [options]' -f $BASENAME)
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -h,--help           Show this help message and exit'
    Write-Output '  -n                  Dry run; only print commands but do not execute them'
    Write-Output ''
    Write-Output '  -B,-Build [dir]     Specify build directory'
    Write-Output ("                      Defaults to: {0}" -f $build_dir)
    Write-Output '  -Clean              Run make clean before building'
    Write-Output '  -CleanAll           Clean everything before building.'
    Write-Output '                      Equivalent to --clean-venv --clean-builddir'
    Write-Output '  -CleanBuildDir      Delete build directory before building'
    Write-Output '  -CleanCache         Re-run CMake with a clean CMake cache'
    Write-Output '  -CleanVenv          Delete Python virtualenv before building'
    Write-Output '  -c,-Configure       Force running the CMake configure step'
    Write-Output '  -ConfigureOnly      Stop after the CMake configure and generation steps (ie. before building MindQuantum)'
    Write-Output '  -Cxx                (experimental) Enable MindQuantum C++ support'
    Write-Output '  -Debug              Build in debug mode'
    Write-Output '  -DebugCMake         Enable debugging mode for CMake configuration step'
    Write-Output '  -Doc, -Docs         Setup the Python virtualenv for building the documentation and ask CMake to build the'
    Write-Output '                      documentation'
    Write-Output '  -Gpu                Enable GPU support'
    Write-Output '  -J,-Jobs [N]        Number of parallel jobs for building'
    Write-Output ("                      Defaults to: {0}" -f $n_jobs_default)
    Write-Output '  -LocalPkgs          Compile third-party dependencies locally'
    Write-Output '  -Quiet              Disable verbose build rules'
    Write-Output '  -ShowLibraries      Show all known third-party libraries'
    Write-Output '  -Venv <path>        Path to Python virtual environment'
    Write-Output ("                      Defaults to: {0}" -f $python_venv_path)
    Write-Output '  -With<library>      Build the third-party <library> from source (<library> is case-insensitive)'
    Write-Output '                      (ignored if --local-pkgs is passed, except for projectq and quest)'
    Write-Output '  -Without<library>   Do not build the third-party library from source (<library> is case-insensitive)'
    Write-Output '                      (ignored if --local-pkgs is passed, except for projectq and quest)'
    Write-Output 'CUDA related options:'
    Write-Output '  -CudaArch <arch>    Comma-separated list of architectures to generate device code for.'
    Write-Output '                      Only useful if --gpu is passed. See CMAKE_CUDA_ARCHITECTURES for more information.'
    Write-Output ''
    Write-Output 'Python related options:'
    Write-Output '  -UpdateVenv         Update the python virtual environment'
    Write-Output ''
    Write-Output 'Any options not matching one of the above will be passed on to CMake during the configuration step'
    Write-Output ''
    Write-Output 'Example calls:'
    Write-Output ("{0} -B build" -f $BASENAME)
    Write-Output ("{0} -B build -gpu" -f $BASENAME)
    Write-Output ("{0} -B build -cxx -WithBoost -Without-Quest" -f $BASENAME)
    Write-Output ("{0} -B build -DCMAKE_CUDA_COMPILER=/opt/cuda/bin/nvcc" -f $BASENAME)
}

# ==============================================================================

if ($n.IsPresent -or $DryRun.IsPresent) {
    $dry_run = 1
}

if ($Clean.IsPresent) {
    $do_clean=1
}
if ($CleanAll.IsPresent) {
    $do_clean_venv = 1
    $do_clean_build_dir = 1
}
if ($CleanBuildDir.IsPresent) {
    $do_clean_build_dir = 1
}
if ($CleanCache.IsPresent) {
    $do_clean_cache = 1
}
if ($CleanVenv.IsPresent) {
    $do_clean_venv = 1
}

if ($C.IsPresent -or $Configure.IsPresent) {
    $do_configure = 1
}
if ($ConfigureOnly.IsPresent) {
    $configure_only = 1
}

if ($Cxx.IsPresent) {
    $enable_cxx = 1
}

if ($Debug.IsPresent) {
    $build_type = "Debug"
}

if ($DebugCMake.IsPresent) {
    $cmake_debug_mode = 1
}

if ($Doc.IsPresent -or $Docs.IsPresent) {
    $do_docs = 1
}

if ($Gpu.IsPresent) {
    $enable_gpu = 1
}

if ($LocalPkgs.IsPresent) {
    $force_local_pkgs = 1
}

if ($Quiet.IsPresent) {
    $cmake_make_silent = 1
}

if ($UpdateVenv.IsPresent) {
    $do_update_venv = 1
}

if ([bool]$B -or [bool]$Build) {
    $build_dir = "$B" + "$Build"
}

if ([bool]$CudaArch) {
    $cuda_arch = $CudaArch.Replace(' ', ';').Replace(',', ';')
}

if ($J -ne 0) {
    $n_jobs = $J
}
elseif ($Jobs -ne 0) {
    $n_jobs = $Jobs
}

if ([bool]$Venv) {
    $python_venv_path = "$Venv"
}

# Parse -With<library> and -Without<library>
$cmake_extra_args = @()

if([bool]$G) {
    $cmake_extra_args += "-G `"$G`""
}
if([bool]$A) {
    $cmake_extra_args += "-A `"$A`""
}

foreach($arg in $args) {
    if ("$arg" -match "[Ww]ith[Oo]ut-?([a-zA-Z0-9_]+)") {
        $enable_lib = 0
        $library = ($Matches[1]).Tolower()
    }
    elseif("$arg" -match "[Ww]ith-?([a-zA-Z0-9_]+)") {
        $enable_lib = 1
        $library = ($Matches[1]).Tolower()
    }
    else {
        $cmake_extra_args += $arg
    }

    if (-Not [bool](($third_party_libraries -eq $library) -join " ")) {
        Write-Output ('Unkown library for {0}' -f $arg)
        exit 1
    }

    if ($library -eq "projectq") {
        $enable_projectq = $enable_lib
    }
    elseif ($library -eq "quest") {
        $enable_quest = $enable_lib
    }
    elseif ($enable_lib -eq 1) {
        $local_pkgs += $library
    }
    else {
        $local_pkgs = $local_pkgs -ne $library
    }
}

$local_pkgs = ($local_pkgs -join ',')


if ($H.IsPresent -or $Help.IsPresent) {
    help_message
    exit 1
}

if($ShowLibraries.IsPresent) {
    print_show_libraries
    exit 1
}

# ==============================================================================
# Locate python or python3

if(Test-CommandExists python3) {
    $PYTHON = "python3"
}
elseif (Test-CommandExists python) {
    $PYTHON = "python"
}
else {
    Write-Output 'Unable to locate python or python3!'
    exit 1
}

# ==============================================================================

$ErrorActionPreference = 'Stop'

cd $BASEPATH

# ------------------------------------------------------------------------------

if ($do_clean_venv -eq 1) {
    Write-Output "Deleting virtualenv folder: $python_venv_path"
    Call-Cmd Remove-Item -Force -Recurse "$python_venv_path" -ErrorAction SilentlyContinue
}

if ($do_clean_build_dir -eq 1) {
    Write-Output "Deleting build folder: $build_dir"
    Call-Cmd Remove-Item -Force -Recurse "$build_dir" -ErrorAction SilentlyContinue
}

$created_venv = 0
if (-Not (Test-Path -Path "$python_venv_path" -PathType Container)) {
    $created_venv = 1
    Write-Output "Creating Python virtualenv: $PYTHON -m venv $python_venv_path"
    Call-Cmd $PYTHON -m venv "$python_venv_path"
}
elseif ($do_update_venv -eq 1) {
    Write-Output "Updating Python virtualenv: $PYTHON -m venv --upgrade $python_venv_path"
    Call-Cmd $PYTHON -m venv --upgrade "$python_venv_path"
}

if($IsWinEnv) {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
}

Write-Output "Activating Python virtual environment: $python_venv_path"
$activate_path = "$python_venv_path\bin\Activate.ps1"
if (Test-Path -Path $BASEPATH\venv\Scripts\activate.ps1 -PathType Leaf) {
    $activate_path = "$python_venv_path\Scripts\Activate.ps1"
}

if ($dry_run -ne 1) {
    . "$activate_path"
} else {
    Write-Output ". $activate_path"
}

# ------------------------------------------------------------------------------
# Locate cmake or cmake3

$has_cmake = 0
$cmake_from_venv = 0

foreach($_cmake in @("$python_venv_path\Scripts\cmake",
                     "$python_venv_path\Scripts\cmake.exe",
                     "$python_venv_path\bin\cmake",
                     "$python_venv_path\bin\cmake.exe")) {
    if(Test-Path -Path "$_cmake") {
        $CMAKE = "$_cmake"
        $has_cmake = 1
        $cmake_from_venv = 1
        break
    }
}

$cmake_minimum_str = Get-Content -TotalCount 40 -Path $BASEPATH\CMakeLists.txt
if ("$cmake_minimum_str" -Match "cmake_minimum_required\(VERSION\s+([0-9\.]+)\)") {
    $cmake_version_min = $Matches[1]
}
else {
    $cmake_version_min = "3.17"
}

if(-Not $has_cmake -eq 1) {
    if(Test-CommandExists cmake3) {
        $CMAKE = "cmake3"
    }
    elseif (Test-CommandExists cmake) {
        $CMAKE = "cmake"
    }

    if ([bool]"$CMAKE") {
        $cmake_version_str = Invoke-Expression -Command "$CMAKE --version"
        if ("$cmake_version_str" -Match "cmake version ([0-9\.]+)") {
            $cmake_version = $Matches[1]
        }

        if ([bool]"$cmake_version" -And [bool]"$cmake_version_min" `
          -And ([System.Version]"$cmake_version_min" -lt [System.Version]"$cmake_version")) {
              $has_cmake=1
          }
    }
}

if ($has_cmake -eq 0) {
    Write-Output "Installing CMake inside the Python virtual environment"
    Call-Cmd $PYTHON -m pip install -U "cmake>=$cmake_version_min"
    foreach($_cmake in @("$python_venv_path\Scripts\cmake",
                         "$python_venv_path\Scripts\cmake.exe",
                         "$python_venv_path\bin\cmake",
                         "$python_venv_path\bin\cmake.exe")) {
        if(Test-Path -Path "$_cmake") {
            $CMAKE = "$_cmake"
            $has_cmake = 1
            $cmake_from_venv = 1
            break
        }
    }
}

# ------------------------------------------------------------------------------


if ($created_venv -eq 1 -or $do_update_venv -eq 1) {
    $pkgs = @("pip", "setuptools", "wheel", "build", "pybind11")

    if($IsLinuxEnv) {
        $pkgs += "auditwheel"
    }
    elseif($IsMacOSEnv) {
        $pkgs += "delocate"
    }

    if($cmake_from_venv) {
        $pkgs += "cmake"
    }

    if($do_docs) {
        $pkgs += "breathe", "sphinx", "sphinx_rtd_theme", "importlib-metadata", "myst-parser"
    }

    # TODO(dnguyen): add wheel delocation package for Windows once we figure this out

    Write-Output ("Updating Python packages: $PYTHON -m pip install -U "  + ($pkgs -Join ' '))
    Call-Cmd $PYTHON -m pip install -U @pkgs
}

if ($dry_run -ne 1) {
    # Make sure the root directory is in the virtualenv PATH
    $site_pkg_dir = Invoke-Expression -Command "$PYTHON -c 'import site; print(site.getsitepackages()[0])'"
    $pth_file = "$site_pkg_dir\mindquantum_local.pth"

    if (-Not (Test-Path -Path "$pth_file" -PathType leaf)) {
        Write-Output "Creating pth-file in $pth_file"
        Write-Output "$BASEPATH" > "$pth_file"
    }
}

# ------------------------------------------------------------------------------
# Setup arguments for build

$cmake_args = @('-DIN_PLACE_BUILD:BOOL=ON'
                '-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON'
                "-DENABLE_PROJECTQ:BOOL={0}" -f $CMAKE_BOOL[$enable_projectq]
                "-DENABLE_QUEST:BOOL={0}" -f $CMAKE_BOOL[$enable_quest]
                "-DENABLE_CMAKE_DEBUG:BOOL={0}" -f $CMAKE_BOOL[$cmake_debug_mode]
                "-DENABLE_CUDA:BOOL={0}" -f $CMAKE_BOOL[$enable_gpu]
                "-DENABLE_CXX_EXPERIMENTAL:BOOL={0}" -f $CMAKE_BOOL[$enable_cxx]
                "-DUSE_VERBOSE_MAKEFILE:BOOL={0}" -f $CMAKE_BOOL[-not $cmake_make_silent]
               )

if ($enable_gpu -eq 1 -and [bool]$cuda_arch) {
    $cmake_args += "-DCMAKE_CUDA_ARCHITECTURES:STRING=`"$cuda_arch`""
}

if ($force_local_pkgs -eq 1) {
    $cmake_args += "-DMQ_FORCE_LOCAL_PKGS=all"
}
elseif ([bool]"$local_pkgs") {
    $cmake_args += "-DMQ_FORCE_LOCAL_PKGS=`"$local_pkgs`""
}

if ($Ninja.IsPresent) {
    $cmake_args += "-GNinja"
}
elseif ($n_jobs -eq -1){
    $n_jobs = $n_jobs_default
}

if($n_jobs -ne -1) {
    $cmake_args += "-DJOBS:STRING={0}" -f $n_jobs
}

# ------------------------------------------------------------------------------
# Build

if (-Not (Test-Path -Path "$build_dir" -PathType Container) -or $do_clean_build_dir -eq 1) {
    $do_configure=1
}
elseif ($do_clean_cache -eq 1) {
    $do_configure=1
    Write-Output "Removing CMake cache at: $build_dir/CMakeCache.txt"
    Call-Cmd Remove-Item -Force "$build_dir/CMakeCache.txt" -ErrorAction SilentlyContinue
    Write-Output "Removing CMake files at: $build_dir/CMakeFiles"
    Call-Cmd Remove-Item -Force -Recurse "$build_dir/CMakeFiles" -ErrorAction SilentlyContinue
}

if ($do_configure -eq 1) {
    Call-CMake -S "$source_dir" -B "$build_dir" @cmake_args @cmake_extra_args
}

if ($configure_only -eq 1) {
    exit 0
}

if ($do_clean -eq 1) {
    Call-CMake --build "$build_dir" --target clean
}

Call-CMake --build "$build_dir" -j "$n_jobs" --config "$build_type"

# ==============================================================================

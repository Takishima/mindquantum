@echo off

rem Copyright 2021 Huawei Technologies Co., Ltd
rem
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem
rem http://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

setlocal ENABLEDELAYEDEXPANSION ENABLEEXTENSIONS

set BASEPATH=%~dp0
set BASENAME=%~nx0

rem ============================================================================
rem Default values

set build_type=Release
set cmake_debug_mode=0
set cmake_make_silent=0
set configure_only=0
set do_clean=0
set do_clean_build_dir=0
set do_clean_cache=0
set do_clean_venv=0
set do_configure=0
set dry_run=0
set enable_cxx=0
set enable_gpu=0
set enable_projectq=1
set enable_quest=0
set force_local_pkgs=0
set ninja=0
set n_jobs=-1
set n_jobs_default=0
for /f  "tokens=2 delims==" %%d in ('wmic cpu get NumberOfLogicalProcessors /value ^| findstr "="') do @set /A n_jobs_default+=%%d >NUL

set source_dir=%BASEPATH%
set build_dir=%BASEPATH%\build
set python_venv_path=%BASEPATH%\venv

set third_party_libraries=boost eigen3 fmt gmp nlohmann_json projectq pybind11 quest symengine tweedledum
set third_party_libraries_N=10

set cmake_book[0]=OFF
set cmake_book[1]=ON

rem ============================================================================

:initial
  set result=false
  if "%1" == "" goto :done_parsing

  if /I "%1" == "/h" set result=true
  if /I "%1" == "/Help" set result=true
  if "%result%" == "true" (
    call :help_message
    goto :EOF
  )

  if /I "%1" == "/n" set result=true
  if "%result%" == "true" (
    set dry_run=1
    shift & goto :initial
  )

  if /I "%1" == "/B" set result=true
  if /I "%1" == "/Build" set result=true
  if "%result%" == "true" (
    set value=%2
    if not defined value goto :arg_build
    if "!value:~0,1!" == "/" (
      :arg_build
      echo %BASENAME%: option requires an argument -- '/B,/Build'
      goto :EOF
    )
    set build_dir=!value!
    shift & shift & goto :initial
  )

  if /I "%1" == "/Clean" (
    set do_clean=1
    shift & goto :initial
  )
  if /I "%1" == "/CleanAll" (
    set do_clean_venv=1
    set do_clean_build_dir=1
    shift & goto :initial
  )
  if /I "%1" == "/CleanCache" (
    set do_clean_cache=1
    shift & goto :initial
  )
  if /I "%1" == "/CleanVenv" (
    set do_clean_venv=1
    shift & goto :initial
  )

  if /I "%1" == "/C" set result=true
  if /I "%1" == "/Configure" set result=true
  if "%result%" == "true" (
    set do_configure=1
    shift & goto :initial
  )
  if /I "%1" == "/ConfigureOnly" (
    set configure_only=1
    shift & goto :initial
  )

  if /I "%1" == "/Cxx" (
    set enable_cxx=1
    shift & goto :initial
  )

  if /I "%1" == "/Debug" (
    set build_type=Debug
    shift & goto :initial
  )

  if /I "%1" == "/DebugCMake" (
    set cmake_debug_mode=1
    shift & goto :initial
  )

  if /I "%1" == "/Gpu" (
    set enable_gpu=1
    shift & goto :initial
  )

  if /I "%1" == "/J" set result=true
  if /I "%1" == "/Jobs" set result=true
  if "%result%" == "true" (
    set value=%2
    if not defined value goto :arg_build
    if "!value:~0,1!" == "/" (
      :arg_build
      echo %BASENAME%: option requires an argument -- '/B,/Build'
      goto :EOF
    )
    set n_jobs=!value!
    shift & shift & goto :initial
  )

  if /I "%1" == "/LocalPkgs" (
    set force_local_pkgs=1
    shift & goto :initial
  )

  if /I "%1" == "/Ninja" (
    set ninja=1
    shift & goto :initial
  )

  if /I "%1" == "/Quiet" (
    set cmake_make_silent=1
    shift & goto :initial
  )

  if /I "%1" == "/ShowLibraries" (
    call :print_show_libraries
    goto :EOF
  )

  if /I "%1" == "/Venv" (
    set value=%2
    if not defined value goto :arg_venv
    if "!value:~0,1!" == "/" (
      :arg_venv
      echo %BASENAME%: option requires an argument -- '/Venv'
      goto :EOF
    )
    set python_venv_path=!value!
    shift & shift & goto :initial
  )

  set value=%1
  set with_header=!value:~0,5!
  if /I "!with_header!" == "/with" (
    set library=!value:~5!
    call :LoCase library
    if not defined local_pkgs (
      set local_pkgs=!library!
    ) else (
      set local_pkgs=!local_pkgs!,!library!
    )
    shift & goto :initial
  )

:done_parsing

rem ----------------------------------------------------------------------------
rem Handle unparsed arguments

:unparsed
  if "%1" == "" goto :done_unparsed
  set unparsed_args=!unparsed_args! %1
  shift

:done_unparsed

rem ============================================================================
rem Locate python or python3

where python3
if %ERRORLEVEL% == 0 (
  set PYTHON=python3
  goto :done_python
)
where python
if %ERRORLEVEL% == 0 (
  set PYTHON=python
  goto :done_python
)

echo Unable to locate python or python3!
goto :EOF

:done_python


rem ============================================================================

cd %BASEPATH%

if !do_clean_venv! == 1 (
  echo Deleting virtualenv folder: !python_venv_path!
  if exist !python_venv_path! call :call_cmd rd /Q /S !python_venv_path!
)

if !do_clean_build_dir! == 1 (
  echo Deleting build folder: !build_dir!
  if exist !build_dir! call :call_cmd rd /Q /S !build_dir!
)

set created_venv=0
if NOT exist !python_venv_path! (
  set created_venv=1
  echo Creating Python virtualenv: !PYTHON! -m venv !python_venv_path!
  call :call_cmd !PYTHON! -m venv !python_venv_path!
)

call :call_cmd !python_venv_path!\Scripts\activate.bat

rem ------------------------------------------------------------------------------
rem Locate cmake or cmake3

rem If from the virtual environment, it's always good
set has_cmake=0
if exist !python_venv_path!\Scripts\cmake.exe (
   set CMAKE=!python_venv_path!\Scripts\cmake.exe
   goto: done_cmake
) else (
  if exist !python_venv_path!\bin\cmake.exe (
     set CMAKE=!python_venv_path!\bin\cmake.exe
     goto: done_cmake
  )
)

rem -------------------------------------

set cmake_version_min=3.17
set cmake_major_min=3
set cmake_minor_min=17

where cmake
if %ERRORLEVEL% == 0 (
   set CMAKE=cmake
   goto :has_cmake
)
where cmake3
if %ERRORLEVEL% == 0 (
   set CMAKE=cmake3
   goto :has_cmake
)

goto :install_cmake

:has_cmake

for /F "tokens=*" %%i in ('cmake --version') do (
  set cmake_version_str=%%i
  goto :done_get_cmake_version
)

:done_get_cmake_version

for %%i in (!cmake_version_str!) do set cmake_version=%%i

for /F "tokens=1,2 delims=." %%a in ("!cmake_version!") do (
    set cmake_major=%%a
    set cmake_minor=%%b
)

if !cmake_major_min! LEQ !cmake_major! (
   if !cmake_minor_min! LEQ !cmake_minor! (
      goto :done_cmake
   )
)

:install_cmake

echo Installing CMake inside the Python virtual environment
call :call_cmd !PYTHON! -m pip install -U "cmake>=!cmake_version_min!"

:done_cmake

rem ------------------------------------------------------------------------------

if !created_venv! == 1 (
  set pkgs=pip setuptools wheel build pybind11

  rem  TODO(dnguyen): add wheel delocation package for Windows once we figure this out

  echo Updating Python packages: !PYTHON! -m pip install -U !pkgs!
  call :call_cmd !PYTHON! -m pip install -U !pkgs!
)

if NOT !dry_run! == 1 (
   for /F %%i in ('!PYTHON! -c "import site; print(site.getsitepackages()[0])"') do set site_pkg_dir=%%i
   set pth_file=!site_pkg_dir!\mindquantum_local.pth

   if NOT exist !pth_file! (
      echo Creating pth-file in !pth_file!
      echo %BASEPATH% > !pth_file!
   )
)

rem ----------------------------------------------------------------------------
rem Setup arguments for build

set cmake_args="-DIN_PLACE_BUILD:BOOL=ON -DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON"

if !cmake_debug_mode! == 1 set cmake_args=!cmake_args! -DENABLE_CMAKE_DEBUG:BOOL=ON

if !cmake_make_silent! == 1 set cmake_args=!cmake_args! -DUSE_VERBOSE_MAKEFILE:BOOL=OFF

if !enable_cxx! == 1 set cmake_args=!cmake_args! -DENABLE_CXX_EXPERIMENTAL:BOOL=ON

if !enable_gpu! == 1 set cmake_args=!cmake_args! -DENABLE_CUDA:BOOL=ON

if !enable_projectq! == 1 (
  set cmake_args=!cmake_args! -DENABLE_PROJECTQ:BOOL=ON
) else (
  set cmake_args=!cmake_args! -DENABLE_PROJECTQ:BOOL=OFF
)

if !enable_quest! == 1 (
  set cmake_args=!cmake_args! -DENABLE_QUEST:BOOL=ON
) else (
  set cmake_args=!cmake_args! -DENABLE_QUEST:BOOL=OFF
)

if !force_local_pkgs! == 1 (
  set cmake_args=!cmake_args! -DMQ_FORCE_LOCAL_PKGS=all
) else (
  if NOT "!local_pkgs!" == "" set cmake_args=!cmake_args! -DMQ_FORCE_LOCAL_PKGS=!local_pkgs!
)

if !ninja! == 1 (
  set cmake_args=!cmake_args! -GNinja
) else (
  if !n_jobs! == -1 set n_jobs=!n_jobs_default!
)

if NOT !n_jobs! == -1 set cmake_args=!cmake_args! -DJOBS:STRING=!n_jobs!

rem ----------------------------------------------------------------------------
rem Build

if NOT exist !build_dir! goto :do_configure
if !do_clean_build_dir! == 1 goto :do_configure

if !do_clean_cache! == 1 (
    echo Removing CMake cache at: !build_dir!\CMakeCache.txt
    if exist !build_dir!\CMakeCache.txt call :call_cmd del /Q "!build_dir!\CMakeCache.txt"
    echo Removing CMake files at: !build_dir!/CMakeFiles
    if exist !build_dir!/CMakeFiles call :call_cmd rd /Q /S "!build_dir!\CMakeFiles"
    goto :do_configure
)

if !do_configure! == 1 goto :do_configure

goto :done_configure

:do_configure
call :call_cmake -S "!source_dir!" -B "!build_dir!" !cmake_args! !unparsed_args!

:done_configure

if !configure_only! == 1 goto :EOF

if !do_clean! == 1 call :call_cmake --build "!build_dir!" --target clean

call :call_cmake --build "!build_dir!" -j !n_jobs! --config !build_type!

goto :EOF

rem ============================================================================

:LoCase
:: Subroutine to convert a variable VALUE to all lower case.
:: The argument for this subroutine is the variable NAME.
set %~1=!%~1:A=a!
set %~1=!%~1:B=b!
set %~1=!%~1:C=c!
set %~1=!%~1:D=d!
set %~1=!%~1:E=e!
set %~1=!%~1:F=f!
set %~1=!%~1:G=g!
set %~1=!%~1:H=h!
set %~1=!%~1:I=i!
set %~1=!%~1:J=j!
set %~1=!%~1:K=k!
set %~1=!%~1:L=l!
set %~1=!%~1:M=m!
set %~1=!%~1:N=n!
set %~1=!%~1:O=o!
set %~1=!%~1:P=p!
set %~1=!%~1:Q=q!
set %~1=!%~1:R=r!
set %~1=!%~1:S=s!
set %~1=!%~1:T=t!
set %~1=!%~1:U=u!
set %~1=!%~1:V=v!
set %~1=!%~1:W=w!
set %~1=!%~1:X=x!
set %~1=!%~1:Y=y!
set %~1=!%~1:Z=z!
exit /B 0

:call_cmd
  if NOT !dry_run! == 1 ( %* ) else (echo %*)
  EXIT /B 0

:call_cmake
  if NOT !dry_run! == 1 (
    echo **********
    echo Calling CMake with: cmake  %*
    echo **********
    cmake %*
  ) else (
    echo cmake %*
  )
  EXIT /B 0

:print_show_libraries
  echo Known third-party libraries:
  for %%a in (%third_party_libraries%) do (
      echo - %%a
  )
  EXIT /B 0

:help_message
  echo Build MindQunantum locally (in-source build)
  echo
  echo This is mainly relevant for developers that do not want to always
  echo have to reinstall the Python package
  echo
  echo This script will create a Python virtualenv in the MindQuantum root
  echo directory and then build all the C++ Python modules and place the
  echo generated libraries in their right locations within the MindQuantum
  echo folder hierarchy so Python knows how to find them.
  echo
  echo A pth-file will be created in the virtualenv site-packages directory
  echo so that the MindQuantum root folder will be added to the Python PATH
  echo without the need to modify PYTHONPATH.
  echo
  echo Usage:
  echo   %BASENAME% [options]
  echo
  echo Options:
  echo   /h,/he lp           Show this help message and exit
  echo   /n                  Dry run; only print commands but do not execute them
  echo
  echo   /B,/Build [dir]     Specify build directory
  echo                       Defaults to: %build_dir%
  echo   /c,/Clean           Run make clean before building
  echo   /CleanAll           Clean everything before building.
  echo                       Equivalent to --clean-venv --clean-builddir
  echo   /CleanBuildDir      Delete build directory before building
  echo   /CleanCache         Re-run CMake with a clean CMake cache
  echo   /CleanVenv          Delete Python virtualenv before building
  echo   /ConfigureOnly      Stop after the CMake configure and generation steps (ie. before building MindQuantum)
  echo   /cxx                (experimental) Enable MindQuantum C++ support
  echo   /Debug              Build in debug mode
  echo   /DebugCMake         Enable debugging mode for CMake configuration step
  echo   /gpu                Enable GPU support
  echo   /j,/Jobs [N]        Number of parallel jobs for building
  echo                       Defaults to: !n_jobs_default!
  echo   /LocalPkgs          Compile third-party dependencies locally
  echo   /Ninja              Use the Ninja CMake generator
  echo   /Quiet              Disable verbose build rules
  echo   /ShowLibraries      Show all known third-party libraries
  echo   /Venv *path*        Path to Python virtual environment
  echo                       Defaults to: %python_venv_path%
  echo   /With*library*      Build the third-party *library* from source (*library* is case-insensitive)
  echo                       (ignored if /LocalPkgs is passed, except for projectq and quest)
  rem echo   /Without*library*   Do not build the third-party library from source (*library* is case-insensitive)
  rem echo                       (ignored if /LocalPkgs is passed, except for projectq and quest)
  echo
  echo NB: at the first unknown option, the argument parsing stops and all options from there onwards are passed onto
  echo     CMake
  echo
  echo Example calls:
  echo %BASENAME% /B build
  echo %BASENAME% /B build /gpu
  echo %BASENAME% /B build /cxx /WithBoost /Without-Quest
  echo %BASENAME% /B build "-DCMAKE_CUDA_COMPILER^=/opt/cuda/bin/nvcc"
  EXIT /B 0

rem ============================================================================

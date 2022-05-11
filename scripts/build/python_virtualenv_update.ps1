# Copyright 2022 Huawei Technologies Co., Ltd
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

if ($_sourced_python_virtualenv_update -eq $null) { $_sourced_python_virtualenv_update=1 } else { return }

$BASEPATH = Split-Path $MyInvocation.MyCommand.Path -Parent

# ------------------------------------------------------------------------------

. "$BASEPATH\default_values.ps1"

. "$BASEPATH\common_functions.ps1"

# ==============================================================================

if ($PYTHON -eq $null) {
    die '(internal error): PYTHON variable not defined!'
}

# ==============================================================================

if ($created_venv -or $do_update_venv) {
    $pkgs = @("pip", "setuptools", "wheel", "build", "pybind11", "setuptools-scm[toml]")

    if($IsLinuxEnv) {
        $pkgs += "auditwheel"
    }
    elseif($IsMacOSEnv) {
        $pkgs += "delocate"
    }

    if($cmake_from_venv) {
        $pkgs += "cmake"
    }

    if($enable_tests) {
        $pkgs += "pytest", "pytest-cov", "pytest-mock"
    }

    if($do_docs) {
        $pkgs += "breathe", "sphinx", "sphinx_rtd_theme", "importlib-metadata", "myst-parser"
    }

    if (-Not $python_extra_pkgs -eq $null) {
        $pkgs += $python_extra_pkgs
    }

    # TODO(dnguyen): add wheel delocation package for Windows once we figure this out

    Write-Output ("Updating Python packages: $PYTHON -m pip install -U "  + ($pkgs -Join ' '))
    Call-Cmd $PYTHON -m pip install -U @pkgs
}

# ==============================================================================

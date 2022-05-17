#!/bin/bash
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

[ "${_sourced_python_virtualenv_update}" != "" ] && return || _sourced_python_virtualenv_update=.

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd )

# ------------------------------------------------------------------------------

# shellcheck source=SCRIPTDIR/default_values.sh
. "$BASEPATH/default_values.sh"

# shellcheck source=SCRIPTDIR/common_functions.sh
. "$BASEPATH/common_functions.sh"

# ==============================================================================

if [ -z "$PYTHON" ]; then
    die '(internal error): PYTHON variable not defined!'
fi

if [ -z "$ROOTDIR" ]; then
    die '(internal error): ROOTDIR variable not defined!'
fi

# ==============================================================================

if [[ ${created_venv:-0} -eq 1 || ${do_update_venv:-0} -eq 1 ]]; then
    pkgs=(pip setuptools wheel build pybind11 setuptools-scm[toml])

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        pkgs+=(auditwheel)
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        pkgs+=(delocate)
    fi

    if [ "${cmake_from_venv:-0}" -eq 1 ]; then
        pkgs+=(cmake)
    fi

    if [ "${enable_tests:-0}" -eq 1 ]; then
        tmp_file=$(mktemp req_mq_XXX)

        pushd "$ROOTDIR" > /dev/null || exit 1
        "$PYTHON" setup.py gen_reqfile --include-extras=tests --output "$tmp_file"
        popd > /dev/null || exit 1

        mapfile -t -O "${#pkgs[@]}" pkgs <<< "$(grep '\S' "$tmp_file")"
        rm -f "$tmp_file"
    fi

    if [ "${do_docs:-0}" -eq 1 ]; then
        pkgs+=(breathe sphinx sphinx_rtd_theme importlib-metadata myst-parser)
    fi

    if [ -n "${python_extra_pkgs[*]}" ]; then
        pkgs+=("${python_extra_pkgs[@]}")
    fi

    pip_args=(--prefer-binary)
    if [[ ${do_update_venv:-0} -eq 1 ]]; then
        pip_args+=( -U )
    fi

    echo "Updating Python packages: $PYTHON -m pip install ${pip_args[*]} ${pkgs[*]}"
    call_cmd "$PYTHON" -m pip install "${pip_args[@]}" "${pkgs[@]}"
fi

# ==============================================================================
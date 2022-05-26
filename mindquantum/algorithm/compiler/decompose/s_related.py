# -*- coding: utf-8 -*-
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
# ============================================================================
"""
CS gate related decompose rule.
"""

from mindquantum.core import gates as G
from mindquantum.core import Circuit
from mindquantum.utils.type_value_check import _check_input_type, _check_control_num
import numpy as np


def cs_decompose(gate: G.SGate):
    """
    Decompose cs gate.

    Args:
        gate (SGate): a SGate with one control qubits.

    Returns:
        List[Circuit], all possible decompose solution.

    Examples:
        >>> from mindquantum.algorithm.compiler.decompose import cs_decompose
        >>> from mindquantum.core import Circuit, S
        >>> cs = S.on(1, 0)
        >>> origin_circ = Circuit() + cs
        >>> decomposed_circ = cs_decompose(cs)[0]
        >>> origin_circ
        q0: ──●──
              │
        q1: ──S──
        >>> decomposed_circ
        q0: ──T────●──────────●──
                   │          │
        q1: ──T────X────T†────X──
        ,
        q0: ──PS(π/4)────●────────────────●──
                         │                │
        q1: ──RZ(π/4)────X────RZ(-π/4)────X──
    """
    _check_input_type('gate', G.SGate, gate)
    _check_control_num(gate.ctrl_qubits, 1)
    solutions = []
    c1 = Circuit()
    solutions.append(c1)
    q0 = gate.ctrl_qubits[0]
    q1 = gate.obj_qubits[0]
    c1 += G.T.on(q0)
    c1 += G.T.on(q1)
    c1 += G.X.on(q1, q0)
    c1 += G.T.on(q1).hermitian()
    c1 += G.X.on(q1, q0)

    c2 = Circuit()
    solutions.append(c2)
    c2 += G.PhaseShift(np.pi/4).on(q0)
    c2 += G.RZ(np.pi/4).on(q1)
    c2 += G.X.on(q1,q0)
    c2 += G.RZ(-np.pi/4).on(q1)
    c2 += G.X.on(q1,q0)
    return solutions

decompose_rules = ['cs_decompose']
__all__ = decompose_rules
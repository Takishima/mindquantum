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
"""Test circuit."""
import numpy as np
from mindquantum import Circuit, Simulator, ParameterResolver
from mindquantum import gates as G


def test_circuit_qubits_grad():
    """
    Description: Test circuit basic operations
    Expectation:
    """
    circuit1 = Circuit()
    circuit1 += G.RX('a').on(0)
    circuit1 *= 2
    circuit2 = Circuit([G.X.on(0, 1)])
    circuit3 = circuit1 + circuit2
    assert len(circuit3) == 3
    assert circuit3.n_qubits == 2
    circuit3.insert(0, G.H.on(0))
    assert circuit3[0] == G.H(0)
    circuit3.no_grad()
    assert len(circuit3[1].coeff.requires_grad_parameters) == 0
    circuit3.requires_grad()
    assert len(circuit3[1].coeff.requires_grad_parameters) == 1
    assert len(circuit3.parameter_resolver()) == 1


def test_circuit_apply():
    """
    Description: Test apply value to parameterized circuit
    Expectation:
    """
    circuit = Circuit()
    circuit += G.RX('a').on(0, 1)
    circuit += G.H.on(0)
    circuit = circuit.apply_value({'a': 0.2})
    circuit_exp = Circuit([G.RX(0.2).on(0, 1), G.H.on(0)])
    assert circuit == circuit_exp


def test_evolution_state():
    """
    test
    Description:
    Expectation:
    """
    a, b = 0.3, 0.5
    circ = Circuit([G.RX('a').on(0), G.RX('b').on(1)])
    s = Simulator('projectq', circ.n_qubits)
    s.apply_circuit(circ, ParameterResolver({'a': a, 'b': b}))
    state = s.get_qs()
    state_exp = [0.9580325796404553, -0.14479246283091116j, -0.2446258794777393j, -0.036971585637570345]
    assert np.allclose(state, state_exp)
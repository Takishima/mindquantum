# -*- coding: utf-8 -*-
#   Copyright 2022 <Huawei Technologies Co., Ltd>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import math
import warnings

import pytest

from mindquantum.experimental import ops, simulator, symengine
from mindquantum.experimental.circuit import Circuit

_has_projectq = True
try:
    import projectq  # noqa: F401
    from projectq import ops as pq_ops
    from projectq.backends import Simulator as PQ_Simulator
    from projectq.cengines import MainEngine
except ImportError:
    _has_projectq = False

has_projectq = pytest.mark.skipif(not _has_projectq, reason='ProjectQ is not installed')

with warnings.catch_warnings():
    warnings.simplefilter('ignore', category=PendingDeprecationWarning)
    PQ_SqrtXInverse = pq_ops.get_inverse(pq_ops.SqrtX)

# ==============================================================================


def angle_idfn(val):
    if isinstance(val, symengine.Basic):
        return 'sym({})'.format(val)
    return 'num({})'.format(val)


# ==============================================================================


def mindquantum_setup(seed, n_qubits):
    circuit = Circuit()
    qubits = []
    for _ in range(n_qubits):
        qubits.append(circuit.create_qubit())

    return (qubits, circuit, simulator.projectq.Simulator(seed))


# ------------------------------------------------------------------------------


def projectq_setup(seed, n_qubits):
    eng = MainEngine(backend=PQ_Simulator(96123), engine_list=[])
    qureg = eng.allocate_qureg(n_qubits)
    return (qureg, eng)


# ==============================================================================


def run_mindquantum(gate, n_qubits, seed):
    qubits, circuit, mq_sim = mindquantum_setup(seed, n_qubits)

    circuit.apply_operator(gate, qubits)
    mq_sim.run_circuit(circuit)

    return mq_sim.cheat()


# ------------------------------------------------------------------------------


def run_projectq(gate, n_qubits, seed):
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', category=PendingDeprecationWarning)

        qubits, eng = projectq_setup(seed, n_qubits)
        if n_qubits == 2:
            gate | (*qubits,)
        else:
            gate | qubits
        eng.flush()
        qubits_map, state = eng.backend.cheat()

        pq_ops.All(pq_ops.Measure) | qubits
        eng.flush()

        return (qubits_map, state)


# ==============================================================================


@pytest.mark.cxx_exp_projectq
@pytest.mark.parametrize(
    "mq_gate, pq_gate",
    [
        (ops.H(), pq_ops.H),
        (ops.X(), pq_ops.X),
        (ops.Y(), pq_ops.Y),
        (ops.Z(), pq_ops.Z),
        (ops.Sx(), pq_ops.SqrtX),
        (ops.Sxdg(), PQ_SqrtXInverse),
        (ops.S(), pq_ops.S),
        (ops.Sdg(), pq_ops.Sdag),
        (ops.T(), pq_ops.T),
        (ops.Tdg(), pq_ops.Tdag),
    ],
    ids=lambda x: f'{str(x)}',
)
@has_projectq
def test_single_qubit_gates(mq_gate, pq_gate):
    """
    Description: Test single qubit gates.
    Expectation: Success
    """
    seed = 98138
    n_qubits = 1

    mq_map, mq_state = run_mindquantum(mq_gate, n_qubits, seed)
    pq_map, pq_state = run_projectq(pq_gate, n_qubits, seed)

    assert mq_map == pq_map
    assert pytest.approx(pq_state) == pq_state


# ------------------------------------------------------------------------------


@pytest.mark.cxx_exp_projectq
@pytest.mark.parametrize(
    "mq_gate, pq_gate",
    [
        (ops.Swap(), pq_ops.Swap),
        (ops.SqrtSwap(), pq_ops.SqrtSwap),
    ],
    ids=lambda x: f'{str(x)}',
)
@has_projectq
def test_two_qubit_gates(mq_gate, pq_gate):
    """
    Description: Test two qubit gates.
    Expectation: Success
    """
    seed = 98138
    n_qubits = 2

    mq_map, mq_state = run_mindquantum(mq_gate, n_qubits, seed)
    pq_map, pq_state = run_projectq(pq_gate, n_qubits, seed)

    assert mq_map == pq_map
    assert pytest.approx(pq_state) == pq_state


# ------------------------------------------------------------------------------


@pytest.mark.cxx_exp_projectq
@pytest.mark.parametrize(
    "angle",
    [
        0,
        0.2,
        2.1,
        4.1,
        2 * math.pi,
        4 * math.pi,
        # sympy.Float(0),
        # sympy.Float(2.1),
        # 2 * sympy.pi,
        # 4 * sympy.pi,
        # sympy.Symbol('x'),
    ],
    ids=angle_idfn,
)
@pytest.mark.parametrize(
    "mq_gate, pq_gate",
    [(ops.Rx, pq_ops.Rx), (ops.Ry, pq_ops.Ry), (ops.Rz, pq_ops.Rz), (ops.P, pq_ops.R), (ops.Ph, pq_ops.Ph)],
    ids=lambda x: f'{str(x.__name__)}',
)
@has_projectq
def test_single_qubit_param_gates(angle, mq_gate, pq_gate):
    """
    Description: Test single qubit single parameter gates.
    Expectation: Success
    """
    seed = 98138
    n_qubits = 1

    mq_map, mq_state = run_mindquantum(mq_gate(angle), n_qubits, seed)
    pq_map, pq_state = run_projectq(pq_gate(angle), n_qubits, seed)

    assert mq_map == pq_map
    assert pytest.approx(pq_state) == pq_state


# ------------------------------------------------------------------------------


@pytest.mark.cxx_exp_projectq
@pytest.mark.parametrize(
    "angle",
    [
        0,
        0.2,
        2.1,
        4.1,
        2 * math.pi,
        4 * math.pi,
        # sympy.Float(0),
        # sympy.Float(2.1),
        # 2 * sympy.pi,
        # 4 * sympy.pi,
        # sympy.Symbol('x'),
    ],
    ids=angle_idfn,
)
@pytest.mark.parametrize(
    "mq_gate, pq_gate",
    [(ops.Rxx, pq_ops.Rxx), (ops.Ryy, pq_ops.Ryy), (ops.Rzz, pq_ops.Rzz)],
    ids=lambda x: f'{str(x.__name__)}',
)
@has_projectq
def test_two_qubit_param_gates(angle, mq_gate, pq_gate):
    """
    Description: Test two qubits single parameter gates.
    Expectation: Success
    """
    seed = 98138
    n_qubits = 2

    mq_map, mq_state = run_mindquantum(mq_gate(angle), n_qubits, seed)
    pq_map, pq_state = run_projectq(pq_gate(angle), n_qubits, seed)

    assert mq_map == pq_map
    assert pytest.approx(pq_state) == pq_state

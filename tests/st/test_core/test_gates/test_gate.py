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

# pylint: disable=invalid-name
"""Test gate."""

import numpy as np
import pytest
from scipy.linalg import expm

import mindquantum.core.gates as G
from mindquantum.core.circuit import UN


def test_rotate_pauli():
    """
    Description: Test rotate pauli
    Expectation:
    """
    gates = {
        'rx': [
            G.RX('angle').on(0),
            lambda phi: np.array([[np.cos(phi / 2), -1j * np.sin(phi / 2)], [-1j * np.sin(phi / 2), np.cos(phi / 2)]]),
        ],
        'ry': [
            G.RY('angle').on(0),
            lambda phi: np.array([[np.cos(phi / 2), -np.sin(phi / 2)], [np.sin(phi / 2), np.cos(phi / 2)]]),
        ],
        'rz': [G.RZ('angle').on(0), lambda phi: np.array([[np.exp(-1j * phi / 2), 0], [0, np.exp(1j * phi / 2)]])],
    }
    angle = 0.5
    for _, rs in gates.items():
        assert np.allclose(rs[0].matrix({'angle': angle}), rs[1](angle))
        assert np.allclose(rs[0].diff_matrix({'angle': angle}), 0.5 * rs[1](angle + np.pi))
        assert np.allclose(rs[0].hermitian().matrix({'angle': angle}), rs[1](-angle))
        assert np.allclose(rs[0].hermitian().diff_matrix({'angle': angle}), 0.5 * rs[1](-angle - np.pi))


def test_phase_shift():
    """
    Description: Test phase shift
    Expectation:
    """
    angle = 0.5

    def f(theta):
        return np.array([[1, 0], [0, np.exp(1.0j * theta)]])

    assert np.allclose(G.PhaseShift(angle).matrix(), f(angle))


def test_trap_ion_gate():
    """
    Description: Test trap ion gate
    Expectation:
    """
    angle = 0.5
    xx = [
        G.XX("angle").on((0, 1)),
        lambda angle: expm(
            -1j
            * angle
            * np.array(
                [
                    [0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 1.0 + 0.0j],
                    [0.0 + 0.0j, 0.0 + 0.0j, 1.0 + 0.0j, 0.0 + 0.0j],
                    [0.0 + 0.0j, 1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
                    [1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
                ]
            )
        ),
    ]
    yy = [
        G.YY("angle").on((0, 1)),
        lambda angle: expm(
            -1j
            * angle
            * np.array(
                [
                    [0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, -1.0 + 0.0j],
                    [0.0 + 0.0j, 0.0 + 0.0j, 1.0 + 0.0j, 0.0 + 0.0j],
                    [0.0 + 0.0j, 1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
                    [-1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
                ]
            )
        ),
    ]
    zz = [
        G.ZZ("angle").on((0, 1)),
        lambda angle: expm(
            -1j
            * angle
            * np.array([[1.0, 0.0, 0.0, 0.0], [0.0, -1.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 0.0, 0.0, 1.0]])
        ),
    ]
    for g in [xx, yy, zz]:
        assert np.allclose(g[0].matrix({'angle': angle}), g[1](angle))
        assert np.allclose(g[0].diff_matrix({'angle': angle}), g[1](angle + np.pi / 2))


def test_pauli_gate():
    """
    Description: Test pauli gate
    Expectation:
    """
    gates = {
        'X': [
            G.X,
            np.array([[0.0 + 0.0j, 1.0 + 0.0j], [1.0 + 0.0j, 0.0 + 0.0j]]),
            lambda phi: np.array([[np.cos(phi / 2), -1j * np.sin(phi / 2)], [-1j * np.sin(phi / 2), np.cos(phi / 2)]]),
        ],
        'Y': [
            G.Y,
            np.array([[0.0 + 0.0j, 0.0 - 1.0j], [0.0 + 1.0j, 0.0 + 0.0j]]),
            lambda phi: np.array([[np.cos(phi / 2), -np.sin(phi / 2)], [np.sin(phi / 2), np.cos(phi / 2)]]),
        ],
        'Z': [
            G.Z,
            np.array([[1.0 + 0.0j, 0.0 + 0.0j], [0.0 + 0.0j, -1.0 + 0.0j]]),
            lambda phi: np.array([[np.exp(-1j * phi / 2), 0], [0, np.exp(1j * phi / 2)]]),
        ],
    }
    angle = 0.5
    for _, ps in gates.items():
        assert np.allclose(ps[0].matrix(), ps[1])
        assert np.allclose((ps[0] ** angle).matrix(), ps[2](angle * np.pi))


def test_identity():
    """
    Description: Test identity
    Expectation:
    """
    assert np.allclose(G.I.matrix(), np.array([[1.0 + 0.0j, 0.0 + 0.0j], [0.0 + 0.0j, 1.0 + 0.0j]]))


def test_hadamard():
    """
    Description: Test hadamard
    Expectation:
    """
    assert np.allclose(
        G.H.matrix(), np.array([[0.70710678 + 0.0j, 0.70710678 + 0.0j], [0.70710678 + 0.0j, -0.70710678 + 0.0j]])
    )


def test_power_ops():
    """
    Description: Test power
    Expectation:
    """
    angle = 0.3
    frac = 0.4
    assert np.allclose(G.Power(G.RX(angle), frac).matrix(), G.RX(angle * frac).matrix())


def test_swap():
    """
    Description: Test swap
    Expectation:
    """
    assert np.allclose(
        G.SWAP.matrix(),
        np.array(
            [
                [1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
                [0.0 + 0.0j, 0.0 + 0.0j, 1.0 + 0.0j, 0.0 + 0.0j],
                [0.0 + 0.0j, 1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
                [0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 1.0 + 0.0j],
            ]
        ),
    )


def test_univ_mat_gate():
    """
    Description: Test UnivMathGate
    Expectation:
    """
    mat = np.random.uniform(size=(2, 2))
    assert np.allclose(G.UnivMathGate('univ', mat).matrix(), mat)


def test_gate_obj_mismatch():
    """
    Description: Test raise gate obj mismatch
    Expectation:
    """
    with pytest.raises(Exception, match=r"requires \d+ qubit"):
        G.X((0, 1))
    with pytest.raises(Exception, match=r"requires \d+ qubit"):
        G.RX('a').on((1, 2), 0)
    with pytest.raises(Exception, match=r"requires \d+ qubit"):
        G.RX(1).on((1, 2), 0)
    with pytest.raises(Exception, match=r"requires \d+ qubit"):
        G.ZZ('a').on(1, 0)


def test_gate_obj_ctrl_overlap():
    """
    Description: Test gate obj ctrl overlap
    Expectation:
    """
    with pytest.raises(Exception, match=r"cannot have same qubits"):
        G.X(1, 1)
    with pytest.raises(Exception, match=r"cannot have same qubits"):
        G.ZZ('a').on((0, 1), (1, 2))
    with pytest.raises(Exception, match=r"cannot have same qubits"):
        G.RX('a').on(1, (1, 2))


def test_global_phase():
    """
    Description: Test global phase gate
    Expectation: success
    """
    c = UN(G.H, 2) + G.GlobalPhase(np.pi).on(1, 0)
    assert np.allclose(c.get_qs(), np.array([0.5, -0.5, 0.5, -0.5]))


def test_u3():
    """
    Description: Test U3 gate
    Expectation: success
    """
    u3 = G.U3('a', 'b', 0.5).on(0)
    assert str(u3) == "U3(𝜃=a, 𝜑=b, 𝜆=1/2|0)"
    assert str(u3.hermitian()) == "U3(𝜃=-a, 𝜑=-1/2, 𝜆=-b|0)"
    m_exp = np.array(
        [[0.87758256 + 0.0j, -0.42073549 - 0.22984885j], [-0.19951142 + 0.43594041j, -0.70306967 + 0.52520872j]]
    )
    assert np.allclose(u3.matrix({'a': 1.0, 'b': 2.0}), m_exp)


def test_fsim():
    """
    Description: Test FSim gate
    Expectation: success
    """
    fsim = G.FSim('a', 0.5).on([0, 1])
    assert str(fsim) == "FSim(𝜃=a, 𝜑=1/2|0 1)"
    assert str(fsim.hermitian()) == "FSim(𝜃=-a, 𝜑=-1/2|0 1)"
    m_exp = np.array(
        [
            [1.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j],
            [0.0 + 0.0j, 0.54030231 + 0.0j, 0.0 - 0.84147098j, 0.0 + 0.0j],
            [0.0 + 0.0j, 0.0 - 0.84147098j, 0.54030231 + 0.0j, 0.0 + 0.0j],
            [0.0 + 0.0j, 0.0 + 0.0j, 0.0 + 0.0j, 0.87758256 + 0.47942554j],
        ]
    )
    assert np.allclose(fsim.matrix({'a': 1.0}), m_exp)

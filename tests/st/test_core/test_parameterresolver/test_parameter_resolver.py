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
"""Test ParameterResolve."""

from mindquantum import ParameterResolver as PR


def test_parameter_resolve():
    """
    Description: Test parameter resolver
    Expectation:
    """
    pr = PR({'a': 1.0})
    pr['b'] = 2.0
    pr[['c', 'd']] = [3.0, 4.0]
    pr *= 2
    pr = pr * 2
    pr = 1 * pr
    pr_tmp = PR({'e': 5.0, 'f': 6.0})
    pr_tmp.no_grad()
    pr.update(pr_tmp)
    assert pr.params_name == ['a', 'b', 'c', 'd', 'e', 'f']
    assert list(pr.para_value) == [4.0, 8.0, 12.0, 16.0, 5.0, 6.0]
    pr.requires_grad_part('e')
    pr.no_grad_part('b')
    assert pr.requires_grad_parameters == {'a', 'c', 'd', 'e'}
    assert pr.no_grad_parameters == {'b', 'f'}
    pr.requires_grad()
    assert not pr.no_grad_parameters


def test_parameter_resolve_dumps_and_loads():
    '''
    Description: Test pr dumps to json and json loads to pr
    Expectation:
    '''
    pr = PR({'a': 1, 'b': 2, 'c': 3, 'd': 4})
    pr.no_grad_part('a', 'b')

    string = pr.dumps()
    obj = PR.loads(string)
    assert obj == pr


def test_parameter_resolve_combination():
    """
    Description: Test pr combination
    Expectation:
    """
    pr1 = PR({'a': 1})
    pr2 = PR({'a': 2, 'b': 3})
    assert pr1.combination(pr2) == 2

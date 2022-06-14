//   Copyright 2021 <Huawei Technologies Co., Ltd>
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

#ifndef GATE_DECOMPOSITION_RULE_CXX20_HPP
#define GATE_DECOMPOSITION_RULE_CXX20_HPP

#include <tuple>
#include <type_traits>

#include "decompositions/config.hpp"
#include "ops/parametric/config.hpp"

#if MQ_HAS_CONCEPTS
#    include "core/gate_concepts.hpp"
#endif  // MQ_HAS_CONCEPTS

#include "decompositions/decomposition_rule.hpp"
#include "decompositions/details/decomposition_param.hpp"

// =============================================================================

namespace mindquantum::decompositions {
template <typename derived_t, typename kinds_t_, DecompositionRuleParam param_ = tparam::default_t, typename... atoms_t>
class GateDecompositionRule
    : public DecompositionRule<derived_t, atoms_t...>
    , public traits::controls<param_.num_controls> {
 public:
    using base_t = GateDecompositionRule;
    using kinds_t = kinds_t_;
    using self_t = GateDecompositionRule<derived_t, kinds_t, param_, atoms_t...>;

    using gate_param_t = ops::parametric::gate_param_t;
    using double_list_t = ops::parametric::double_list_t;
    using param_list_t = ops::parametric::param_list_t;

    // ---------------------------------------------------------------------

    using DecompositionRule<derived_t, atoms_t...>::DecompositionRule;

    // ---------------------------------------------------------------------

    //! Return the number of target qubits this DecompositionRule is constrained on
    static constexpr auto num_targets() noexcept {
        return param_.num_targets;
    }

    //! Return the number of control qubits this DecompositionRule is constrained on
    static constexpr auto num_controls() noexcept {
        return param_.num_controls;
    }

    //! Constant boolean indicating whether the GateDecompositionRule is parametric or not
    static constexpr auto is_parametric = param_.num_params != 0U;

    //! Return the number of parameters of this GateDecompositionRule
    static constexpr auto num_params() noexcept {
        return param_.num_params;
    }

    // ---------------------------------------------------------------------

    //! Check whether a decomposition is compatible with another one.
    /*!
     * Another GateDecompositionRule instance is deemed compatible iff:
     *   - the number of target qubit are identical
     *   - the number of controls are compatible:
     *      - the number of control qubits in the decomposition rule is left undefined
     *      - or they have the same number of controls
     *
     * \param num_targets Number of target qubits of the operation to decompose
     * \param num_controls Number of control qubits of the operation to decompose
     */
    // TODO(dnguyen): constrain `rule_t` to decomposition atoms
    template <typename rule_t>
    MQ_NODISCARD constexpr bool is_compatible() const noexcept;

    //! Check whether a decomposition is applicable with a given instruction
    /*!
     * \param inst A quantum instruction
     */
    MQ_NODISCARD bool is_applicable(const instruction_t& inst) const noexcept;

    // -----------------------------
};
}  // namespace mindquantum::decompositions

#include "decompositions/details/gate_decomposition_rule_cxx20.tpp"

#endif /* GATE_DECOMPOSITION_RULE_CXX20_HPP */

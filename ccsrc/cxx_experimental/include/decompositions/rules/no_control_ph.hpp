//   Copyright 2022 <Huawei Technologies Co., Ltd>
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

#ifndef DECOMPOSITION_RULE_NO_CONTROL_PH
#define DECOMPOSITION_RULE_NO_CONTROL_PH

#include <algorithm>

#include "core/config.hpp"
#include "decompositions/rules/config.hpp"

#include "decompositions/non_gate_decomposition_rule.hpp"
#include "ops/gates.hpp"
#include "ops/parametric/angle_gates.hpp"

namespace mindquantum::decompositions::rules {
    class RemovePhNoCtrl : public decompositions::NonGateDecompositionRule<RemovePhNoCtrl> {
     public:
        using base_t::base_t;

        static constexpr auto name() noexcept {
            return "CNOT2CZ"sv;
        }

        HIQ_NODISCARD static bool is_applicable(const decompositions::instruction_t& inst) {
            return inst.is_one<ops::Ph, ops::parametric::Ph>() && inst.num_controls() == 0;
        }

        void apply_impl(circuit_t& /* circuit */, const instruction_t& /* inst */) {
        }
    };
}  // namespace mindquantum::decompositions::rules
#endif /* DECOMPOSITION_RULE_NO_CONTROL_PH */

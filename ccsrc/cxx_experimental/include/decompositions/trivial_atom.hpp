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

#ifndef TRIVIAL_ATOM_HPP
#define TRIVIAL_ATOM_HPP

#include <cstdint>

#include "core/config.hpp"
#include "decompositions/config.hpp"

#include "core/operator_traits.hpp"
#include "decompositions/atom_storage.hpp"

namespace mindquantum::decompositions {
//! A decomposition atom representing a gate with no free-parameter
/*!
 * \note This can be a parametric gate with all of its parameters fully specified
 *
 *  \tparam operator_t Type of the gate the atom is representing
 *  \tparam num_controls_ Number of control qubits the gate this atom is representing has. Possible values:
 *                        -1 for any number of control qubits, >= 0 for a specified number of control qubits.
 */
template <typename operator_t, num_target_t num_targets_ = any_target, num_control_t num_controls_ = any_control>
class TrivialAtom : public traits::controls<num_controls_> {
 public:
    using self_t = TrivialAtom<operator_t, num_targets_, num_controls_>;
    using kinds_t = std::tuple<operator_t>;

    explicit TrivialAtom(AtomStorage& /* storage */) {
        // NB: TrivialAtom has no dependent atoms to insert into the storage
    }

    //! Return the name of this decomposition atom
    MQ_NODISCARD static constexpr std::string_view name() noexcept {
        return operator_t::kind();
    }

    //! Return the number of target qubits this decomposition atom is constrained on
    MQ_NODISCARD static constexpr auto num_targets() noexcept {
        return num_targets_;
    }

    //! Return the number of control qubits this decomposition atom is constrained on
    MQ_NODISCARD static constexpr auto num_controls() noexcept {
        return num_controls_;
    }

    //! Return the number of parameters of this decomposition atom
    MQ_NODISCARD static constexpr auto num_params() noexcept {
        return num_param_t{0UL};
    }

    //! Helper function to create an instance of this atom
    /*!
     * \param storage Atom storage within which this decomposition will live in
     */
    MQ_NODISCARD static auto create(AtomStorage& storage) noexcept {
        return self_t{storage};
    }

    // ---------------------------------------------------------------------

    //! Test whether this atom is applicable to a particular instruction
    /*!
     * \param inst An instruction
     * \return True if the atom can be applied, false otherwise
     */
    MQ_NODISCARD bool is_applicable(const instruction_t& inst) const noexcept;

    //! Apply the atom (ie. the decomposition it represents) to a quantum circuit
    /*!
     * \param circuit A quantum circuit to apply the decomposition atom to
     * \param op A quantum operation to decompose
     * \param qubits A list of qubits to apply the decomposition atom
     * \param cbits A list of classical bit the decomposition applies to
     *
     * \note Currently the \c cbits parameter is not used at all! It is here to make the API futureproof.
     */
    void apply(circuit_t& circuit, const decompositions::operator_t& op, const qubits_t& qubits,
               const cbits_t& cbits) noexcept;
};

template <typename operator_t, num_control_t num_controls_ = any_control>
using TrivialSimpleAtom = TrivialAtom<operator_t, traits::num_targets<operator_t>, num_controls_>;
}  // namespace mindquantum::decompositions

#include "decompositions/trivial_atom.tpp"

#endif /* TRIVIAL_ATOM_HPP */

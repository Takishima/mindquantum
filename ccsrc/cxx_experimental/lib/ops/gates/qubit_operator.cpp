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

#include "ops/gates/qubit_operator.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <functional>
#include <numeric>
#include <optional>
#include <string_view>
#include <tuple>
#include <type_traits>
#include <utility>
#include <vector>

// IMPORTANT: do not include boost/fusion/include/std_pair.hpp!
#include <boost/fusion/include/adapt_struct.hpp>
#include <boost/spirit/home/x3.hpp>

#include <tweedledum/Operators/Standard/X.h>
#include <tweedledum/Operators/Standard/Y.h>
#include <tweedledum/Operators/Standard/Z.h>

#include <fmt/format.h>

#ifdef ENABLE_LOGGING
#    include <spdlog/spdlog.h>
#endif  // ENABLE_LOGGING

#include "core/parser/boost_x3_error_handler.hpp"
#include "details/boost_x3_parse_term.hpp"
#include "ops/gates.hpp"
#include "ops/gates/terms_operator.hpp"

namespace mindquantum::ops {
constexpr std::tuple<std::complex<double>, TermValue> pauli_products(const TermValue& left_op,
                                                                     const TermValue& right_op) {
    if (left_op == TermValue::I && right_op == TermValue::X) {
        return {1., TermValue::X};
    }
    if (left_op == TermValue::X && right_op == TermValue::I) {
        return {1., TermValue::X};
    }
    if (left_op == TermValue::I && right_op == TermValue::Y) {
        return {1., TermValue::Y};
    }
    if (left_op == TermValue::Y && right_op == TermValue::I) {
        return {1., TermValue::Y};
    }
    if (left_op == TermValue::I && right_op == TermValue::Z) {
        return {1., TermValue::Z};
    }
    if (left_op == TermValue::Z && right_op == TermValue::I) {
        return {1., TermValue::Z};
    }
    if (left_op == TermValue::X && right_op == TermValue::X) {
        return {1., TermValue::I};
    }
    if (left_op == TermValue::Y && right_op == TermValue::Y) {
        return {1., TermValue::I};
    }
    if (left_op == TermValue::Z && right_op == TermValue::Z) {
        return {1., TermValue::I};
    }
    if (left_op == TermValue::X && right_op == TermValue::Y) {
        return {{0, 1.}, TermValue::Z};
    }
    if (left_op == TermValue::X && right_op == TermValue::Z) {
        return {{0, -1.}, TermValue::Y};
    }
    if (left_op == TermValue::Y && right_op == TermValue::X) {
        return {{0, -1.}, TermValue::Z};
    }
    if (left_op == TermValue::Y && right_op == TermValue::Z) {
        return {{0, 1.}, TermValue::X};
    }
    if (left_op == TermValue::Z && right_op == TermValue::X) {
        return {{0, 1.}, TermValue::Y};
    }
    if (left_op == TermValue::Z && right_op == TermValue::Y) {
        return {{0, -1.}, TermValue::X};
    }

    return {1., TermValue::I};
}

// =============================================================================

QubitOperator::QubitOperator(term_t term, coefficient_t coeff) : TermsOperator(std::move(term), coeff) {
}

// -----------------------------------------------------------------------------

QubitOperator::QubitOperator(const std::vector<term_t>& term, coefficient_t coeff) : TermsOperator(term, coeff) {
}

// -----------------------------------------------------------------------------

QubitOperator::QubitOperator(complex_term_dict_t terms) : TermsOperator(std::move(terms)) {
}

// =============================================================================

uint32_t QubitOperator::count_gates() const noexcept {
    return std::accumulate(begin(terms_), end(terms_), 0UL, [](const auto& val, const auto& term) {
        const auto& [ops, coeff] = term;
        return val + std::size(ops);
    });
}
// =============================================================================

auto QubitOperator::matrix(std::optional<uint32_t> n_qubits) const -> std::optional<csr_matrix_t> {
    namespace Op = tweedledum::Op;
    using dense_2x2_t = Eigen::Matrix2cd;

    // NB: required since we are indexing into the array below
    static_assert(static_cast<std::underlying_type_t<TermValue>>(TermValue::I) == 0);
    static_assert(static_cast<std::underlying_type_t<TermValue>>(TermValue::X) == 1);
    static_assert(static_cast<std::underlying_type_t<TermValue>>(TermValue::Y) == 2);
    static_assert(static_cast<std::underlying_type_t<TermValue>>(TermValue::Z) == 3);

    static const std::array<csr_matrix_t, 4> pauli_matrices = {
        dense_2x2_t::Identity().sparseView(),
        Op::X::matrix().sparseView(),
        Op::Y::matrix().sparseView(),
        Op::Z::matrix().sparseView(),
    };

    if (std::empty(terms_)) {
        return std::nullopt;
    }

    // NB: this is assuming that num_targets_ is up-to-date
    const auto& n_qubits_local = num_targets_;

    if (n_qubits_local == 0UL && !n_qubits) {
        std::cerr << "You should specify n_qubits for converting an identity qubit operator.";
        return std::nullopt;
    }

    if (n_qubits && n_qubits.value() < n_qubits_local) {
        std::cerr << fmt::format(
            "Given n_qubits {} is smaller than the number of qubits of this qubit operator, which is {}.\n",
            n_qubits.value(), n_qubits_local);
        return std::nullopt;
    }

    const auto n_qubits_value = n_qubits.value_or(n_qubits_local);

    const auto process_term = [n_qubits_value](const auto& local_ops, const auto& coeff) -> csr_matrix_t {
        if (std::empty(local_ops)) {
            return (Eigen::Matrix<std::complex<double>, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>::Identity(
                        1U << n_qubits_value, 1U << n_qubits_value))
                       .sparseView()
                   * coeff;
        }

        // TODO(dnguyen): The `total` variable is probably not required and could be removed altogether...
        std::vector<csr_matrix_t> total(n_qubits_value,
                                        pauli_matrices[static_cast<std::underlying_type_t<TermValue>>(TermValue::I)]);
        for (const auto& [qubit_id, local_op] : local_ops) {
            total[qubit_id] = pauli_matrices[static_cast<std::underlying_type_t<TermValue>>(local_op)];
        }

        csr_matrix_t init(1, 1);
        init.insert(0, 0) = coeff;
        return std::accumulate(begin(total), end(total), init, [](const csr_matrix_t& init, const auto& matrix) {
            return Eigen::kroneckerProduct(matrix, init).eval();
        });
    };

    auto it = begin(terms_);
    auto result = process_term(it->first, it->second);
    ++it;
    for (; it != end(terms_); ++it) {
        result += process_term(it->first, it->second);
    }

    return result;
}

// =============================================================================

auto QubitOperator::split() const noexcept -> std::vector<QubitOperator> {
    std::vector<QubitOperator> result;
    for (const auto& [local_ops, coeff] : terms_) {
        result.emplace_back(local_ops, coeff);
    }
    return result;
}

// =============================================================================

auto QubitOperator::simplify_(std::vector<term_t> terms, coefficient_t coeff)
    -> std::tuple<std::vector<term_t>, coefficient_t> {
    if (std::empty(terms)) {
        return {std::vector<term_t>{}, coeff};
    }
    std::sort(
        begin(terms), end(terms), [](const auto& lhs, const auto& rhs) constexpr { return lhs.first < rhs.first; });

    std::vector<term_t> reduced_terms;
    auto left_term = terms.front();
    for (auto it(begin(terms) + 1); it != end(terms); ++it) {
        const auto& [left_qubit_id, left_operator] = left_term;
        const auto& [right_qubit_id, right_operator] = *it;

        if (left_qubit_id == right_qubit_id) {
            const auto [new_coeff, new_op] = pauli_products(left_operator, right_operator);
            left_term = term_t{left_qubit_id, new_op};
            coeff *= new_coeff;
        } else {
            if (left_term.second != TermValue::I) {
                reduced_terms.emplace_back(left_term);
            }
            left_term = *it;
        }
    }

    return {std::move(terms), coeff};
}
}  // namespace mindquantum::ops

// =============================================================================

namespace x3 = boost::spirit::x3;

namespace ast {
using mindquantum::ops::TermValue;
using term_t = mindquantum::ops::QubitOperator::term_t;

struct TermOp : x3::symbols<TermValue> {
    TermOp() {
        add("X", TermValue::X)("Y", TermValue::Y)("Z", TermValue::Z);
    }
} const term_op;

// NB: This struct is required to re-order the parsed values since the local_op appears *before* the qubit index in the
//     string
struct qubit_operator_term {
    TermValue local_op;
    uint32_t qubit_id;

    operator term_t() const& {  // NOLINT(google-explicit-constructor,hicpp-explicit-conversions)
        return {qubit_id, local_op};
    }
    operator term_t() && {  // NOLINT(google-explicit-constructor,hicpp-explicit-conversions)
        return {qubit_id, local_op};
    }
};
}  // namespace ast

BOOST_FUSION_ADAPT_STRUCT(ast::qubit_operator_term, local_op, qubit_id);

// -----------------------------------------------------------------------------

namespace parser {
struct local_op_sym_class {};
x3::rule<local_op_sym_class, ast::TermValue> const local_op_sym = "local operator (X, Y, Z)";
static const auto local_op_sym_def = ast::term_op;

struct unsigned_value_class {};
x3::rule<unsigned_value_class, uint32_t> const unsigned_value = "unsigned int";
static const auto unsigned_value_def = x3::uint_;

struct term_class : mindquantum::parser::x3::rule::error_handler {};
x3::rule<term_class, ast::qubit_operator_term> const term = "qubit_operator term";
static const auto term_def = x3::eps > local_op_sym > unsigned_value > x3::omit[*x3::space];

BOOST_SPIRIT_DEFINE(local_op_sym, unsigned_value, term);

// -------------------------------------

static const auto terms = +term;
}  // namespace parser

// -----------------------------------------------------------------------------

namespace mindquantum::ops {

auto QubitOperator::parse_string_(std::string_view terms_string) -> std::vector<term_t> {
    using terms_t = std::vector<term_t>;
    if (terms_t terms; parser::parse_term(begin(terms_string), end(terms_string), terms, ::parser::terms)) {
        return terms;
    }
    return {};
}

// =============================================================================
}  // namespace mindquantum::ops

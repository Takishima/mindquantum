#ifndef SQRTSWAP_HPP
#define SQRTSWAP_HPP

#include <array>
#include <string_view>

#include <tweedledum/Utils/Matrix.h>

#include "ops/meta/dagger.hpp"

namespace mindquantum::ops {
namespace td = tweedledum;

// SqrtSwap operator
class SqrtSwap {
    // clang-format off
          constexpr static std::array<td::Complex, 16> mat_ = {
               1, 0, 0, 0,
               0, td::Complex(0.5, 0.5), td::Complex(0.5, -0.5), 0,
               0, td::Complex(0.5, -0.5), td::Complex(0.5, 0.5), 0,
               0, 0, 0, 1
          };
    // clang-format on

 public:
    static constexpr std::string_view kind() {
        return "projectq.sqrtswap";
    }

    uint32_t num_targets() const {
        return 2u;
    }

    td::Operator adjoint() const {
        return DaggerOperation(*this);
    }

    static td::UMatrix4 const matrix() {
        return Eigen::Map<td::UMatrix4 const>(mat_.data());
    }
};

}  // namespace mindquantum::ops

#endif /* SQRTSWAP_HPP */

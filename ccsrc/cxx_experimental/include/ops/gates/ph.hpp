#ifndef PH_HPP
#define PH_HPP

#include <string_view>

#include <tweedledum/IR/Operator.h>
#include <tweedledum/Utils/Matrix.h>

namespace mindquantum::ops {
class Ph {
    using UMatrix2 = tweedledum::UMatrix2;

 public:
    static constexpr std::string_view kind() {
        return "projectq.ph";
    }

    static constexpr auto num_params = 1UL;

    Ph(double angle) : angle_(angle) {
    }

    Ph adjoint() const {
        return Ph(-angle_);
    }

    constexpr bool is_symmetric() const {
        return true;
    }

    UMatrix2 const matrix() const {
        using Complex = tweedledum::Complex;
        Complex const a = std::exp(Complex(0., angle_));
        return (UMatrix2() << a, 0., 0., a).finished();
    }

    bool operator==(Ph const& other) const {
        return angle_ == other.angle_;
    }

    const auto& angle() const {
        return angle_;
    }

 private:
    double const angle_;
};
}  // namespace mindquantum::ops

#endif /* PH_HPP */

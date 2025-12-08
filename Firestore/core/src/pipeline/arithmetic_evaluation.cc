#include "Firestore/core/src/pipeline/arithmetic_evaluation.h"

#include <cmath>
#include <limits>
#include <utility>

#include "Firestore/core/src/pipeline/util_evaluation.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

EvaluateResult EvaluateAdd::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  auto const result = SafeAdd(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateAdd::PerformDoubleOperation(double l, double r) const {
  return EvaluateResult::NewValue(DoubleValue(l + r));
}

EvaluateResult EvaluateSubtract::PerformIntegerOperation(int64_t l,
                                                         int64_t r) const {
  auto const result = SafeSubtract(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateSubtract::PerformDoubleOperation(double l,
                                                        double r) const {
  return EvaluateResult::NewValue(DoubleValue(l - r));
}

EvaluateResult EvaluateMultiply::PerformIntegerOperation(int64_t l,
                                                         int64_t r) const {
  auto const result = SafeMultiply(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateMultiply::PerformDoubleOperation(double l,
                                                        double r) const {
  return EvaluateResult::NewValue(DoubleValue(l * r));
}

EvaluateResult EvaluateDivide::PerformIntegerOperation(int64_t l,
                                                       int64_t r) const {
  auto const result = SafeDivide(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateDivide::PerformDoubleOperation(double l,
                                                      double r) const {
  // C++ double division handles signed zero correctly according to IEEE
  // 754. +x / +0 -> +Inf -x / +0 -> -Inf +x / -0 -> -Inf -x / -0 -> +Inf
  //  0 /  0 -> NaN
  return EvaluateResult::NewValue(DoubleValue(l / r));
}

EvaluateResult EvaluateMod::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  auto const result = SafeMod(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateMod::PerformDoubleOperation(double l, double r) const {
  if (r == 0.0) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  // Use std::fmod for double modulo, matches C++ and Firestore semantics
  return EvaluateResult::NewValue(DoubleValue(std::fmod(l, r)));
}

EvaluateResult EvaluatePow::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  // Promote to double, as std::pow for integers is complex and can overflow.
  return PerformDoubleOperation(static_cast<double>(l), static_cast<double>(r));
}

EvaluateResult EvaluatePow::PerformDoubleOperation(double l, double r) const {
  if (r == 0.0 || l == 1.0) {
    return EvaluateResult::NewValue(DoubleValue(1.0));
  }
  if (l == -1.0 && std::isinf(r)) {
    return EvaluateResult::NewValue(DoubleValue(1.0));
  }
  if (std::isnan(l) || std::isnan(r)) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  // Check for non-integer exponent on a negative base
  if (l < 0 && std::isfinite(l) && (r != std::floor(r))) {
    return EvaluateResult::NewError();
  }
  if ((l == 0.0 || l == -0.0) && r < 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::pow(l, r)));
}

EvaluateResult EvaluateRoundToPrecision::PerformIntegerOperation(
    int64_t l, int64_t r) const {
  if (r >= 0) {
    return EvaluateResult::NewValue(IntValue(l));
  }
  double num_digits =
      std::floor(std::log10(std::abs(static_cast<double>(l)))) + 1;
  if (-r >= num_digits) {
    return EvaluateResult::NewValue(IntValue(0));
  }
  double rounding_factor_double = std::pow(10.0, -static_cast<double>(r));
  int64_t rounding_factor = static_cast<int64_t>(rounding_factor_double);

  int64_t truncated = l - (l % rounding_factor);

  if (std::abs(l % rounding_factor) < (rounding_factor / 2)) {
    return EvaluateResult::NewValue(IntValue(truncated));
  }

  if (l < 0) {
    if (l < std::numeric_limits<int64_t>::min() + rounding_factor)
      return EvaluateResult::NewError();
    return EvaluateResult::NewValue(IntValue(truncated - rounding_factor));
  } else {
    if (l > std::numeric_limits<int64_t>::max() - rounding_factor)
      return EvaluateResult::NewError();
    return EvaluateResult::NewValue(IntValue(truncated + rounding_factor));
  }
}

EvaluateResult EvaluateRoundToPrecision::PerformDoubleOperation(
    double l, double r) const {
  int64_t places = static_cast<int64_t>(r);
  if (places >= 16 || !std::isfinite(l)) {
    return EvaluateResult::NewValue(DoubleValue(l));
  }
  double num_digits = std::floor(std::log10(std::abs(l))) + 1;
  if (-places >= num_digits) {
    return EvaluateResult::NewValue(DoubleValue(0.0));
  }
  double factor = std::pow(10.0, places);
  double result = std::round(l * factor) / factor;

  if (std::isfinite(result)) {
    return EvaluateResult::NewValue(DoubleValue(result));
  }
  return EvaluateResult::NewError();  // overflow
}

EvaluateResult EvaluateLog::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  return PerformDoubleOperation(static_cast<double>(l), static_cast<double>(r));
}

EvaluateResult EvaluateLog::PerformDoubleOperation(double l, double r) const {
  if (std::isinf(l) && l < 0) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  if (std::isinf(r)) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  if (l <= 0 || r <= 0 || r == 1.0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::log(l) / std::log(r)));
}

EvaluateResult EvaluateCeil::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::ceil(val)));
}

EvaluateResult EvaluateFloor::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::floor(val)));
}

EvaluateResult EvaluateRound::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::round(val)));
}

EvaluateResult EvaluateAbs::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::abs(val)));
}

EvaluateResult EvaluateExp::PerformOperation(double val) const {
  double result = std::exp(val);
  if (std::isinf(result) && !std::isinf(val)) {
    return EvaluateResult::NewError();  // Overflow
  }
  return EvaluateResult::NewValue(DoubleValue(result));
}

EvaluateResult EvaluateLn::PerformOperation(double val) const {
  if (val <= 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::log(val)));
}

EvaluateResult EvaluateLog10::PerformOperation(double val) const {
  if (val <= 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::log10(val)));
}

EvaluateResult EvaluateSqrt::PerformOperation(double val) const {
  if (val < 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::sqrt(val)));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

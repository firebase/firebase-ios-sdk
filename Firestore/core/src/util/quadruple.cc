//  Copyright 2025 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#include "quadruple.h"
#include <ctype.h>
#include <stdint.h>
#include <cmath>
#include <limits>
#include "quadruple_builder.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {
constexpr int64_t kHashCodeOfNan = 7652541255;
}

Quadruple::Quadruple(double x) {
  negative_ = signbit(x);
  switch (fpclassify(x)) {
    case FP_NAN:
      negative_ = false;
      exponent_ = kInfiniteExponent;
      mantissa_hi_ = 1ULL << 63;
      mantissa_lo_ = 0;
      break;
    case FP_INFINITE:
      exponent_ = kInfiniteExponent;
      mantissa_hi_ = 0;
      mantissa_lo_ = 0;
      break;
    case FP_ZERO:
      exponent_ = 0;
      mantissa_hi_ = 0;
      mantissa_lo_ = 0;
      break;
    case FP_SUBNORMAL:
    case FP_NORMAL:
      negative_ = x < 0;
      int x_exponent;
      double small = frexp(std::abs(x), &x_exponent);
      exponent_ = static_cast<uint32_t>(x_exponent - 1) + kExponentBias;
      // Scale 'small' to its 53-bit mantissa value as a long, then left-justify
      // it with the leading 1 bit dropped in mantissa_hi (65-53=12).
      mantissa_hi_ = static_cast<uint64_t>(ldexp(small, 53)) << 12;
      mantissa_lo_ = 0;
      break;
  }
}
Quadruple::Quadruple(int64_t x) {
  if (x == 0) {
    negative_ = false;
    exponent_ = 0;
    mantissa_hi_ = 0;
    mantissa_lo_ = 0;
  } else if (x == std::numeric_limits<int64_t>::min()) {
    // -2^63 cannot be negated, so special-case it.
    negative_ = true;
    exponent_ = 63 + kExponentBias;
    mantissa_hi_ = 0;
    mantissa_lo_ = 0;
  } else {
    negative_ = x < 0;
    if (negative_) {
      x = -x;
    }
    if (x == 1) {
      // The shift below wraps around for x=1, so special-case it.
      exponent_ = kExponentBias;
      mantissa_hi_ = 0;
      mantissa_lo_ = 0;
    } else {
      uint64_t ux = static_cast<uint64_t>(x);
      int leading_zeros = __builtin_clzll(ux);
      // Left-justify with the leading 1 dropped.
      mantissa_hi_ = ux << (leading_zeros + 1);
      mantissa_lo_ = 0;
      exponent_ = static_cast<uint32_t>(63 - leading_zeros) + kExponentBias;
    }
  }
}
bool Quadruple::Parse(std::string s) {
  if (s == "NaN") {
    negative_ = false;
    exponent_ = kInfiniteExponent;
    mantissa_hi_ = 1LL << 63;
    mantissa_lo_ = 0;
    return true;
  }
  if (s == "-Infinity") {
    negative_ = true;
    exponent_ = kInfiniteExponent;
    mantissa_hi_ = 0;
    mantissa_lo_ = 0;
    return true;
  }
  if (s == "Infinity" || s == "+Infinity") {
    negative_ = false;
    exponent_ = kInfiniteExponent;
    mantissa_hi_ = 0;
    mantissa_lo_ = 0;
    return true;
  }
  bool negative = false;
  int len = s.size();
  uint8_t* digits = new uint8_t[len];
  int i = 0;
  int j = 0;
  int64_t exponent = 0;
  if (i < len) {
    if (s[i] == '-') {
      negative = true;
      i++;
    } else if (s[i] == '+') {
      i++;
    }
  }
  while (i < len && isdigit(s[i])) {
    digits[j++] = static_cast<uint8_t>(s[i++] - '0');
  }
  if (i < len && s[i] == '.') {
    int decimal = ++i;
    while (i < len && isdigit(s[i])) {
      digits[j++] = static_cast<uint8_t>(s[i++] - '0');
    }
    exponent = decimal - i;
  }
  if (i < len && (s[i] == 'e' || s[i] == 'E')) {
    int64_t exponentValue = 0;
    i++;
    int exponentSign = 1;
    if (i < len) {
      if (s[i] == '-') {
        exponentSign = -1;
        i++;
      } else if (s[i] == '+') {
        i++;
      }
    }
    int firstExponent = i;
    while (i < len && isdigit(s[i])) {
      exponentValue = exponentValue * 10 + s[i++] - '0';
      if (i - firstExponent > 9) {
        return false;
      }
    }
    if (i == firstExponent) {
      return false;
    }
    exponent += exponentValue * exponentSign;
  }
  if (j == 0 || i != len) {
    return false;
  }
  std::vector<uint8_t> digits_copy(j);
  for (int k = 0; k < j; k++) {
    digits_copy[k] = digits[k];
  }
  QuadrupleBuilder parsed;
  parsed.parseDecimal(digits_copy, exponent);
  negative_ = negative;
  exponent_ = parsed.exponent;
  mantissa_hi_ = parsed.mantHi;
  mantissa_lo_ = parsed.mantLo;
  return true;
}
// Compare two quadruples, with -0 < 0, and NaNs larger than all numbers.
int Quadruple::Compare(const Quadruple& other) const {
  int lessThan;
  int greaterThan;
  if (negative_) {
    if (!other.negative_) {
      return -1;
    }
    lessThan = 1;
    greaterThan = -1;
  } else {
    if (other.negative_) {
      return 1;
    }
    lessThan = -1;
    greaterThan = 1;
  }
  if (exponent_ < other.exponent_) {
    return lessThan;
  } else if (exponent_ > other.exponent_) {
    return greaterThan;
  } else if (mantissa_hi_ < other.mantissa_hi_) {
    return lessThan;
  } else if (mantissa_hi_ > other.mantissa_hi_) {
    return greaterThan;
  } else if (mantissa_lo_ < other.mantissa_lo_) {
    return lessThan;
  } else if (mantissa_lo_ > other.mantissa_lo_) {
    return greaterThan;
  } else {
    return 0;
  }
}
Quadruple::operator double() const {
  switch (exponent_) {
    case 0:
      // zero or Quadruple subnormal
      return negative_ ? -0.0 : 0.0;
    case kInfiniteExponent: {
      if (is_nan()) {
        return NAN;
      }
      return negative_ ? -INFINITY : INFINITY;
    }
    default:
      int32_t unbiased_exp = static_cast<int32_t>(exponent_ - kExponentBias);
      return scalb((1LL << 52) | (mantissa_hi_ >> 12), -52 + unbiased_exp) *
             (negative_ ? -1 : 1);
  }
}
int64_t Quadruple::HashValue() const {
  if (is_nan()) {
    return kHashCodeOfNan;
  }
  const int64_t prime = 31;
  int64_t result = 1;
  result = prime * result + static_cast<uint64_t>(exponent_);
  result = prime * result + static_cast<uint64_t>(mantissa_hi_);
  result = prime * result + static_cast<uint64_t>(mantissa_lo_);
  result = prime * result + (negative_ ? 1231 : 1237);
  return result;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
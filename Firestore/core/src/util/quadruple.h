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

#include <stdint.h>
#include <iomanip>
#include <ios>
#include <sstream>
#include <string>

#ifndef FIRESTORE_CORE_UTIL_QUADRUPLE_H_
#define FIRESTORE_CORE_UTIL_QUADRUPLE_H_

namespace firebase {
namespace firestore {
namespace util {

// A minimal C++ implementation of a 128-bit mantissa / 32-bit exponent binary
// floating point number equivalent to https://github.com/m-vokhm/Quadruple
//
// Supports:
// - creation from string
// - creation from serialised format (3 longs), long and double
// - comparisons
class Quadruple {
 public:
  // Initialises a Quadruple to +0.0
  Quadruple() : Quadruple(0, 0, 0) {
  }

  Quadruple(uint64_t exponent_and_sign,
            uint64_t mantissa_hi,
            uint64_t mantissa_lo)
      : negative_(exponent_and_sign >> 63),
        exponent_(static_cast<uint32_t>(exponent_and_sign)),
        mantissa_hi_(mantissa_hi),
        mantissa_lo_(mantissa_lo) {
  }
  explicit Quadruple(double x);
  explicit Quadruple(int64_t x);
  // Updates this Quadruple with the decimal number specified in s.
  // Returns true for valid numbers, false for invalid numbers.
  // The Quadruple is unchanged if the result is false.
  //
  // The supported format (no whitespace allowed) is:
  // - NaN, Infinity, +Infinity, -Infinity for the corresponding constants
  // - a string matching [+-]?[0-9]*(.[0-9]*)?([eE][+-]?[0-9]+)?
  //   with the exponent at most 9 characters, and the whole string not empty
  bool Parse(std::string s);
  // Rounds out-of-range numbers to +/- 0/HUGE_VAL. Rounds towards 0.
  explicit operator double() const;
  // Compare two quadruples, with -0 < 0, and NaNs larger than all numbers.
  int Compare(const Quadruple& other) const;
  bool operator==(const Quadruple& other) const {
    return Compare(other) == 0;
  }
  bool is_nan() const {
    return (exponent_ == kInfiniteExponent) &&
           !(mantissa_hi_ == 0 && mantissa_lo_ == 0);
  }
  // The actual exponent is exponent_-kExponentBias.
  static const uint32_t kExponentBias = 0x7FFFFFFF;
  int64_t HashValue() const;
  std::string DebugString() {
    std::stringstream out;
    if (negative_) {
      out << "-";
    }
    out << "1x" << std::hex << std::setfill('0');
    out << std::setw(16) << mantissa_hi_;
    out << std::setw(16) << mantissa_lo_;
    out << "*2^" << std::dec << exponent_ - static_cast<int64_t>(kExponentBias);
    out << " =~ " << static_cast<double>(*this);

    return out.str();
  }

 private:
  static const uint32_t kInfiniteExponent = 0xFFFFFFFF;  // including its bias
  bool negative_;
  uint32_t exponent_;
  uint64_t mantissa_hi_;
  uint64_t mantissa_lo_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_UTIL_QUADRUPLE_H_
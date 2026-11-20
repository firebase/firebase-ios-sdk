/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "Firestore/core/src/util/quadruple.h"

#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

// Integers whose magnitude is at most 2^53 are exactly representable as
// doubles, so Quadruple(int64_t) and Quadruple(double) must agree on them.
std::vector<int64_t> ExactlyRepresentableIntegers() {
  std::vector<int64_t> values = {0,          255,        12345,
                                 1000000007, 0x7FFFFFFF, 1LL << 53};
  for (int shift = 0; shift < 53; ++shift) {
    values.push_back(1LL << shift);
    values.push_back((1LL << shift) | 1);
    values.push_back((1LL << shift) - 1);
  }
  std::vector<int64_t> result;
  for (int64_t v : values) {
    result.push_back(v);
    result.push_back(-v);
  }
  return result;
}

TEST(QuadrupleTest, Int64ConstructorMatchesDoubleConstructor) {
  for (int64_t v : ExactlyRepresentableIntegers()) {
    EXPECT_EQ(Quadruple(v).Compare(Quadruple(static_cast<double>(v))), 0)
        << "value: " << v;
  }
}

TEST(QuadrupleTest, Int64RoundTripsThroughDouble) {
  for (int64_t v : ExactlyRepresentableIntegers()) {
    EXPECT_EQ(static_cast<double>(Quadruple(v)), static_cast<double>(v))
        << "value: " << v;
  }
}

TEST(QuadrupleTest, Int64ExtremesConvertToDouble) {
  const int64_t max = std::numeric_limits<int64_t>::max();
  const int64_t min = std::numeric_limits<int64_t>::min();
  // Conversion to double truncates the mantissa rather than rounding.
  EXPECT_EQ(static_cast<double>(Quadruple(min)), std::ldexp(-1.0, 63));
  EXPECT_EQ(static_cast<double>(Quadruple(max)),
            std::ldexp(1.0, 63) - std::ldexp(1.0, 63 - 53));
  EXPECT_EQ(static_cast<double>(Quadruple(min + 1)),
            -(std::ldexp(1.0, 63) - std::ldexp(1.0, 63 - 53)));
  EXPECT_LT(Quadruple(max - 1).Compare(Quadruple(max)), 0);
  EXPECT_GT(Quadruple(min + 1).Compare(Quadruple(min)), 0);
}

TEST(QuadrupleTest, Int64OrderingIsPreserved) {
  std::vector<int64_t> ordered = {std::numeric_limits<int64_t>::min(),
                                  -(1LL << 62) - 1,
                                  -(1LL << 62),
                                  -3,
                                  -2,
                                  -1,
                                  0,
                                  1,
                                  2,
                                  3,
                                  (1LL << 62),
                                  (1LL << 62) + 1,
                                  std::numeric_limits<int64_t>::max()};
  for (size_t i = 0; i + 1 < ordered.size(); ++i) {
    EXPECT_LT(Quadruple(ordered[i]).Compare(Quadruple(ordered[i + 1])), 0)
        << ordered[i] << " vs " << ordered[i + 1];
  }
}

TEST(QuadrupleTest, ParsedIntegersMatchInt64Constructor) {
  for (int64_t v : ExactlyRepresentableIntegers()) {
    Quadruple parsed;
    ASSERT_TRUE(parsed.Parse(std::to_string(v))) << "value: " << v;
    EXPECT_EQ(parsed.Compare(Quadruple(v)), 0) << "value: " << v;
  }
  const int64_t max = std::numeric_limits<int64_t>::max();
  Quadruple parsed_max;
  ASSERT_TRUE(parsed_max.Parse(std::to_string(max)));
  EXPECT_EQ(parsed_max.Compare(Quadruple(max)), 0);
}

TEST(QuadrupleTest, ParsedDecimalsConvertToNearbyDouble) {
  for (const char* s :
       {"0.5", "1.25", "123.456", "-98765.4321", "1e-10", "6.02214076e23"}) {
    Quadruple parsed;
    ASSERT_TRUE(parsed.Parse(s)) << s;
    double expected = std::stod(s);
    // Conversion to double truncates, so allow one ulp of difference.
    EXPECT_NEAR(static_cast<double>(parsed), expected,
                std::abs(expected) * std::numeric_limits<double>::epsilon())
        << s;
  }
}

}  // namespace
}  // namespace util
}  // namespace firestore
}  // namespace firebase

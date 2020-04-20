/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/util/comparison.h"

#include <cmath>
#include <limits>

#include "Firestore/core/src/util/string_format.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

#define ASSERT_SAME(comparison)                    \
  do {                                             \
    ASSERT_EQ(ComparisonResult::Same, comparison); \
  } while (0)

#define ASSERT_ASCENDING(comparison)                    \
  do {                                                  \
    ASSERT_EQ(ComparisonResult::Ascending, comparison); \
  } while (0)

#define ASSERT_DESCENDING(comparison)                    \
  do {                                                   \
    ASSERT_EQ(ComparisonResult::Descending, comparison); \
  } while (0)

TEST(Comparison, ReverseOrder) {
  ASSERT_ASCENDING(ReverseOrder(ComparisonResult::Descending));
  ASSERT_DESCENDING(ReverseOrder(ComparisonResult::Ascending));
  ASSERT_SAME(ReverseOrder(ComparisonResult::Same));
}

TEST(Comparison, StringCompare) {
  ASSERT_ASCENDING(Compare<absl::string_view>("", "a"));
  ASSERT_ASCENDING(Compare<absl::string_view>("a", "b"));
  ASSERT_ASCENDING(Compare<absl::string_view>("a", "aa"));

  ASSERT_DESCENDING(Compare<absl::string_view>("a", ""));
  ASSERT_DESCENDING(Compare<absl::string_view>("b", "a"));
  ASSERT_DESCENDING(Compare<absl::string_view>("aa", "a"));

  ASSERT_SAME(Compare<absl::string_view>("", ""));
  ASSERT_SAME(Compare<absl::string_view>("", std::string()));
  ASSERT_SAME(Compare<absl::string_view>("a", "a"));
}

TEST(Comparison, BooleanCompare) {
  ASSERT_SAME(Compare<bool>(false, false));
  ASSERT_SAME(Compare<bool>(true, true));
  ASSERT_ASCENDING(Compare<bool>(false, true));
  ASSERT_DESCENDING(Compare<bool>(true, false));
}

TEST(Comparison, DoubleCompare) {
  ASSERT_SAME(Compare<double>(NAN, NAN));
  ASSERT_ASCENDING(Compare<double>(NAN, 0));
  ASSERT_DESCENDING(Compare<double>(0, NAN));

  ASSERT_SAME(Compare<double>(-INFINITY, -INFINITY));
  ASSERT_SAME(Compare<double>(INFINITY, INFINITY));
  ASSERT_ASCENDING(Compare<double>(-INFINITY, INFINITY));
  ASSERT_DESCENDING(Compare<double>(INFINITY, -INFINITY));

  ASSERT_SAME(Compare<double>(0, 0));
  ASSERT_SAME(Compare<double>(-0, -0));
  ASSERT_SAME(Compare<double>(-0, 0));
}

#define ASSERT_BIT_EQUALS(expected, actual)              \
  do {                                                   \
    uint64_t expected_bits = DoubleBits(expected);       \
    uint64_t actual_bits = DoubleBits(actual);           \
    if (expected_bits != actual_bits) {                  \
      std::string message = StringFormat(                \
          "Expected <%s> to compare equal to <%s> "      \
          "with bits <%s> equal to <%s>",                \
          actual, expected, actual_bits, expected_bits); \
      FAIL() << message;                                 \
    }                                                    \
  } while (0);

#define ASSERT_MIXED_SAME(double_value, long_value)                            \
  do {                                                                         \
    ComparisonResult result = CompareMixedNumber(double_value, long_value);    \
    if (result != ComparisonResult::Same) {                                    \
      std::string message = StringFormat(                                      \
          "Expected <%s> to compare equal to <%s>", double_value, long_value); \
      FAIL() << message;                                                       \
    }                                                                          \
  } while (0);

#define ASSERT_MIXED_DESCENDING(double_value, long_value)                      \
  do {                                                                         \
    ComparisonResult result = CompareMixedNumber(double_value, long_value);    \
    if (result != ComparisonResult::Descending) {                              \
      std::string message = StringFormat(                                      \
          "Expected <%s> to compare equal to <%s>", double_value, long_value); \
      FAIL() << message;                                                       \
    }                                                                          \
  } while (0);

#define ASSERT_MIXED_ASCENDING(double_value, long_value)                       \
  do {                                                                         \
    ComparisonResult result = CompareMixedNumber(double_value, long_value);    \
    if (result != ComparisonResult::Ascending) {                               \
      std::string message = StringFormat(                                      \
          "Expected <%s> to compare equal to <%s>", double_value, long_value); \
      FAIL() << message;                                                       \
    }                                                                          \
  } while (0);

TEST(Comparison, MixedNumberCompare) {
  // Infinities
  ASSERT_MIXED_ASCENDING(-INFINITY, LLONG_MIN);
  ASSERT_MIXED_ASCENDING(-INFINITY, LLONG_MAX);
  ASSERT_MIXED_ASCENDING(-INFINITY, 0LL);

  ASSERT_MIXED_DESCENDING(INFINITY, LLONG_MIN);
  ASSERT_MIXED_DESCENDING(INFINITY, LLONG_MAX);
  ASSERT_MIXED_DESCENDING(INFINITY, 0LL);

  // NaN
  ASSERT_MIXED_ASCENDING(NAN, LLONG_MIN);
  ASSERT_MIXED_ASCENDING(NAN, LLONG_MAX);
  ASSERT_MIXED_ASCENDING(NAN, 0LL);

  // Large values (note DBL_MIN is positive and near zero).
  ASSERT_MIXED_ASCENDING(-DBL_MAX, LLONG_MIN);

  // Tests around LLONG_MIN
  ASSERT_BIT_EQUALS((double)LLONG_MIN, -0x1.0p63);
  ASSERT_MIXED_SAME(-0x1.0p63, LLONG_MIN);
  ASSERT_MIXED_ASCENDING(-0x1.0p63, LLONG_MIN + 1);

  ASSERT_LT(-0x1.0000000000001p63, -0x1.0p63);
  ASSERT_MIXED_ASCENDING(-0x1.0000000000001p63, LLONG_MIN);
  ASSERT_MIXED_DESCENDING(-0x1.FFFFFFFFFFFFFp62, LLONG_MIN);

  // Tests around LLONG_MAX
  // Note LLONG_MAX cannot be exactly represented by a double, so the system
  // rounds it to the nearest double, which is 2^63. This number, in turn is
  // larger than the maximum representable as a long.
  ASSERT_BIT_EQUALS(0x1.0p63, (double)LLONG_MAX);
  ASSERT_MIXED_DESCENDING(0x1.0p63, LLONG_MAX);

  // The largest value with an exactly long representation
  ASSERT_EQ((int64_t)0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFC00LL);
  ASSERT_MIXED_SAME(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFC00LL);

  ASSERT_MIXED_DESCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFB00LL);
  ASSERT_MIXED_DESCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFBFFLL);
  ASSERT_MIXED_ASCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFC01LL);
  ASSERT_MIXED_ASCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFD00LL);

  ASSERT_MIXED_ASCENDING(0x1.FFFFFFFFFFFFEp62, 0x7FFFFFFFFFFFFC00LL);

  // Tests around MAX_SAFE_INTEGER
  ASSERT_MIXED_SAME(0x1.FFFFFFFFFFFFFp52, 0x1FFFFFFFFFFFFFLL);
  ASSERT_MIXED_DESCENDING(0x1.FFFFFFFFFFFFFp52, 0x1FFFFFFFFFFFFELL);
  ASSERT_MIXED_ASCENDING(0x1.FFFFFFFFFFFFEp52, 0x1FFFFFFFFFFFFFLL);
  ASSERT_MIXED_ASCENDING(0x1.FFFFFFFFFFFFFp52, 0x20000000000000LL);

  // Tests around MIN_SAFE_INTEGER
  ASSERT_MIXED_SAME(-0x1.FFFFFFFFFFFFFp52, -0x1FFFFFFFFFFFFFLL);
  ASSERT_MIXED_ASCENDING(-0x1.FFFFFFFFFFFFFp52, -0x1FFFFFFFFFFFFELL);
  ASSERT_MIXED_DESCENDING(-0x1.FFFFFFFFFFFFEp52, -0x1FFFFFFFFFFFFFLL);
  ASSERT_MIXED_DESCENDING(-0x1.FFFFFFFFFFFFFp52, -0x20000000000000LL);

  // Tests around zero.
  ASSERT_MIXED_SAME(-0.0, 0LL);
  ASSERT_MIXED_SAME(0.0, 0LL);

  // The smallest representable positive value should be greater than zero
  ASSERT_MIXED_DESCENDING(DBL_MIN, 0LL);
  ASSERT_MIXED_ASCENDING(-DBL_MIN, 0LL);

  // Note that 0x1.0p-1074 is a hex floating point literal representing the
  // minimum subnormal number: <https://en.wikipedia.org/wiki/Denormal_number>.
  double min_sub_normal = 0x1.0p-1074;
  ASSERT_MIXED_DESCENDING(min_sub_normal, 0LL);
  ASSERT_MIXED_ASCENDING(-min_sub_normal, 0LL);

  // Other sanity checks
  ASSERT_MIXED_ASCENDING(0.5, 1LL);
  ASSERT_MIXED_DESCENDING(0.5, 0LL);
  ASSERT_MIXED_ASCENDING(1.5, 2LL);
  ASSERT_MIXED_DESCENDING(1.5, 1LL);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

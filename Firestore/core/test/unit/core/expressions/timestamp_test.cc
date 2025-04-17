/*
 * Copyright 2025 Google LLC
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

#include <limits>
#include <memory>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"  // Include gMock
#include "gtest/gtest.h"  // Include gTest

namespace firebase {
namespace firestore {
namespace core {

using ::firebase::Timestamp;  // Correct namespace
using testutil::EvaluateExpr;
using testutil::Returns;
// using testutil::ReturnsError; // Remove using declaration
using testutil::SharedConstant;
using testutil::SubtractExpr;  // Needed for overflow tests
using testutil::UnixMicrosToTimestampExpr;
using testutil::Value;

// Base fixture for common setup (if needed later)
class TimestampExpressionsTest : public ::testing::Test {};

// Fixture for UnixMicrosToTimestamp function tests
class UnixMicrosToTimestampTest : public TimestampExpressionsTest {};

TEST_F(UnixMicrosToTimestampTest, StringTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant("abc"))),
              testutil::ReturnsError());  // Fully qualify
}

TEST_F(UnixMicrosToTimestampTest, ZeroValueReturnsTimestampEpoch) {
  EXPECT_THAT(EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(0LL))),
              Returns(Value(Timestamp(0, 0))));
}

TEST_F(UnixMicrosToTimestampTest, IntTypeReturnsTimestamp) {
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(1000000LL))),
      Returns(Value(Timestamp(1, 0))));
}

TEST_F(UnixMicrosToTimestampTest, LongTypeReturnsTimestamp) {
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(9876543210LL))),
      Returns(Value(Timestamp(9876, 543210000))));
}

TEST_F(UnixMicrosToTimestampTest, LongTypeNegativeReturnsTimestamp) {
  // -10000 micros = -0.01 seconds = -10,000,000 nanos
  google_firestore_v1_Value timestamp;
  timestamp.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  timestamp.timestamp_value.seconds = -1;
  timestamp.timestamp_value.nanos = 990000000;
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(-10000LL))),
      Returns(nanopb::MakeMessage(timestamp)));
}

TEST_F(UnixMicrosToTimestampTest, LongTypeNegativeOverflowReturnsError) {
  // Min representable timestamp: seconds=-62135596800, nanos=0
  // Corresponds to micros: -62135596800 * 1,000,000 = -62135596800000000
  const int64_t min_micros = -62135596800000000LL;

  // Test the boundary value
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(min_micros))),
      Returns(Value(Timestamp(-62135596800LL, 0))));

  // Test value just below the boundary (using subtraction)
  auto below_min_expr =
      SubtractExpr({SharedConstant(min_micros), SharedConstant(1LL)});
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(std::move(below_min_expr))),
      testutil::ReturnsError());  // Fully qualify
}

TEST_F(UnixMicrosToTimestampTest, LongTypePositiveOverflowReturnsError) {
  // Max representable timestamp: seconds=253402300799, nanos=999999999
  // Corresponds to micros: 253402300799 * 1,000,000 + 999999
  // = 253402300799000000 + 999999 = 253402300799999999
  const int64_t max_micros = 253402300799999999LL;

  // Test the boundary value
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(max_micros))),
      Returns(Value(Timestamp(253402300799LL, 999999000))));  // Nanos truncated

  // Test value just above the boundary
  // max_micros + 1 = 253402300800000000
  EXPECT_THAT(
      EvaluateExpr(*UnixMicrosToTimestampExpr(SharedConstant(max_micros + 1))),
      testutil::ReturnsError());  // Fully qualify
}

// Fixture for UnixMillisToTimestamp function tests
class UnixMillisToTimestampTest : public TimestampExpressionsTest {};

using testutil::UnixMillisToTimestampExpr;  // Add using declaration for this
                                            // fixture

TEST_F(UnixMillisToTimestampTest, StringTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant("abc"))),
              testutil::ReturnsError());
}

TEST_F(UnixMillisToTimestampTest, ZeroValueReturnsTimestampEpoch) {
  EXPECT_THAT(EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(0LL))),
              Returns(Value(Timestamp(0, 0))));
}

TEST_F(UnixMillisToTimestampTest, IntTypeReturnsTimestamp) {
  EXPECT_THAT(EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(1000LL))),
              Returns(Value(Timestamp(1, 0))));
}

TEST_F(UnixMillisToTimestampTest, LongTypeReturnsTimestamp) {
  EXPECT_THAT(
      EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(9876543210LL))),
      Returns(Value(Timestamp(9876543, 210000000))));
}

TEST_F(UnixMillisToTimestampTest, LongTypeNegativeReturnsTimestamp) {
  EXPECT_THAT(
      EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(-10000LL))),
      Returns(Value(Timestamp(-10, 0))));
}

TEST_F(UnixMillisToTimestampTest, LongTypeNegativeOverflowReturnsError) {
  // Min representable timestamp: seconds=-62135596800, nanos=0
  // Corresponds to millis: -62135596800 * 1000 = -62135596800000
  const int64_t min_millis = -62135596800000LL;

  // Test the boundary value
  EXPECT_THAT(
      EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(min_millis))),
      Returns(Value(Timestamp(-62135596800LL, 0))));

  // Test value just below the boundary
  EXPECT_THAT(
      EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(min_millis - 1))),
      testutil::ReturnsError());
}

TEST_F(UnixMillisToTimestampTest, LongTypePositiveOverflowReturnsError) {
  // Max representable timestamp: seconds=253402300799, nanos=999999999
  // Corresponds to millis: 253402300799 * 1000 + 999 = 253402300799999
  const int64_t max_millis = 253402300799999LL;

  // Test the boundary value
  EXPECT_THAT(
      EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(max_millis))),
      Returns(Value(Timestamp(253402300799LL, 999000000))));

  // Test value just above the boundary
  EXPECT_THAT(
      EvaluateExpr(*UnixMillisToTimestampExpr(SharedConstant(max_millis + 1))),
      testutil::ReturnsError());
}

// Fixture for UnixSecondsToTimestamp function tests
class UnixSecondsToTimestampTest : public TimestampExpressionsTest {};

using testutil::UnixSecondsToTimestampExpr;  // Add using declaration

TEST_F(UnixSecondsToTimestampTest, StringTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant("abc"))),
              testutil::ReturnsError());
}

TEST_F(UnixSecondsToTimestampTest, ZeroValueReturnsTimestampEpoch) {
  EXPECT_THAT(EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant(0LL))),
              Returns(Value(Timestamp(0, 0))));
}

TEST_F(UnixSecondsToTimestampTest, IntTypeReturnsTimestamp) {
  EXPECT_THAT(EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant(1LL))),
              Returns(Value(Timestamp(1, 0))));
}

TEST_F(UnixSecondsToTimestampTest, LongTypeReturnsTimestamp) {
  EXPECT_THAT(
      EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant(9876543210LL))),
      Returns(Value(Timestamp(9876543210LL, 0))));
}

TEST_F(UnixSecondsToTimestampTest, LongTypeNegativeReturnsTimestamp) {
  EXPECT_THAT(
      EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant(-10000LL))),
      Returns(Value(Timestamp(-10000LL, 0))));
}

TEST_F(UnixSecondsToTimestampTest, LongTypeNegativeOverflowReturnsError) {
  // Min representable timestamp: seconds=-62135596800, nanos=0
  const int64_t min_seconds = -62135596800LL;

  // Test the boundary value
  EXPECT_THAT(
      EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant(min_seconds))),
      Returns(Value(Timestamp(min_seconds, 0))));

  // Test value just below the boundary
  EXPECT_THAT(EvaluateExpr(
                  *UnixSecondsToTimestampExpr(SharedConstant(min_seconds - 1))),
              testutil::ReturnsError());
}

TEST_F(UnixSecondsToTimestampTest, LongTypePositiveOverflowReturnsError) {
  // Max representable timestamp: seconds=253402300799, nanos=999999999
  const int64_t max_seconds = 253402300799LL;

  // Test the boundary value (max seconds, zero nanos)
  EXPECT_THAT(
      EvaluateExpr(*UnixSecondsToTimestampExpr(SharedConstant(max_seconds))),
      Returns(Value(Timestamp(max_seconds, 0))));

  // Test value just above the boundary
  EXPECT_THAT(EvaluateExpr(
                  *UnixSecondsToTimestampExpr(SharedConstant(max_seconds + 1))),
              testutil::ReturnsError());
}

// Fixture for TimestampToUnixMicros function tests
class TimestampToUnixMicrosTest : public TimestampExpressionsTest {};

using testutil::TimestampToUnixMicrosExpr;  // Add using declaration

TEST_F(TimestampToUnixMicrosTest, NonTimestampTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(123LL))),
              testutil::ReturnsError());
}

TEST_F(TimestampToUnixMicrosTest, TimestampReturnsMicros) {
  Timestamp ts(347068800, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(ts))),
              Returns(Value(347068800000000LL)));
}

TEST_F(TimestampToUnixMicrosTest, EpochTimestampReturnsMicros) {
  Timestamp ts(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(ts))),
              Returns(Value(0LL)));
}

TEST_F(TimestampToUnixMicrosTest, CurrentTimestampReturnsMicros) {
  // Note: C++ doesn't have a direct equivalent to JS Timestamp.now() easily
  // accessible here. We'll test with a known value instead.
  Timestamp now(1678886400,
                123456000);  // Example: March 15, 2023 12:00:00.123456 UTC
  int64_t expected_micros = 1678886400LL * 1000000LL + 123456LL;
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(now))),
              Returns(Value(expected_micros)));
}

TEST_F(TimestampToUnixMicrosTest, MaxTimestampReturnsMicros) {
  // Max representable timestamp: seconds=253402300799, nanos=999999999
  Timestamp max_ts(253402300799LL, 999999999);
  // Expected micros: 253402300799 * 1,000,000 + 999999 = 253402300799999999
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(max_ts))),
              Returns(Value(253402300799999999LL)));
}

TEST_F(TimestampToUnixMicrosTest, MinTimestampReturnsMicros) {
  // Min representable timestamp: seconds=-62135596800, nanos=0
  Timestamp min_ts(-62135596800LL, 0);
  // Expected micros: -62135596800 * 1,000,000 = -62135596800000000
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(min_ts))),
              Returns(Value(-62135596800000000LL)));
}

TEST_F(TimestampToUnixMicrosTest, TimestampOverflowReturnsError) {
  // Create a timestamp value slightly outside the representable int64_t range
  // for microseconds. This requires constructing the Value proto directly.
  // Using MAX_SAFE_INTEGER from JS isn't directly applicable, focus on int64
  // limits. A timestamp with seconds > INT64_MAX / 1,000,000 will overflow.
  // Let's use a value known to be problematic.
  // Note: The original JS test uses MAX_SAFE_INTEGER which is ~2^53. C++
  // int64_t is 2^63. The actual overflow check happens internally based on
  // int64_t limits for micros. We expect the internal conversion to fail if the
  // result exceeds int64 limits. Let's test with a timestamp whose microsecond
  // equivalent *would* overflow int64_t. Example: seconds slightly larger than
  // INT64_MAX / 1,000,000
  google_firestore_v1_Value timestamp_proto;
  timestamp_proto.timestamp_value.seconds =
      9223372036855LL;  // > INT64_MAX / 1M
  timestamp_proto.timestamp_value.nanos = 0;
  timestamp_proto.which_value_type =
      google_firestore_v1_Value_timestamp_value_tag;

  EXPECT_THAT(
      EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(timestamp_proto))),
      testutil::ReturnsError());
}

TEST_F(TimestampToUnixMicrosTest, TimestampTruncatesToMicros) {
  // Timestamp: seconds=-1, nanos=999999999
  // Micros: -1 * 1,000,000 + 999999 = -1
  Timestamp ts(-1, 999999999);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMicrosExpr(SharedConstant(ts))),
              Returns(Value(-1LL)));
}

// Fixture for TimestampToUnixMillis function tests
class TimestampToUnixMillisTest : public TimestampExpressionsTest {};

using testutil::TimestampToUnixMillisExpr;  // Add using declaration

TEST_F(TimestampToUnixMillisTest, NonTimestampTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(123LL))),
              testutil::ReturnsError());
}

TEST_F(TimestampToUnixMillisTest, TimestampReturnsMillis) {
  Timestamp ts(347068800, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(ts))),
              Returns(Value(347068800000LL)));
}

TEST_F(TimestampToUnixMillisTest, EpochTimestampReturnsMillis) {
  Timestamp ts(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(ts))),
              Returns(Value(0LL)));
}

TEST_F(TimestampToUnixMillisTest, CurrentTimestampReturnsMillis) {
  // Test with a known value
  Timestamp now(1678886400,
                123000000);  // Example: March 15, 2023 12:00:00.123 UTC
  int64_t expected_millis = 1678886400LL * 1000LL + 123LL;
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(now))),
              Returns(Value(expected_millis)));
}

TEST_F(TimestampToUnixMillisTest, MaxTimestampReturnsMillis) {
  // Max representable timestamp: seconds=253402300799, nanos=999999999
  // Millis calculation truncates nanos part: 999999999 / 1,000,000 = 999
  Timestamp max_ts(253402300799LL,
                   999000000);  // Use nanos divisible by 1M for clarity
  // Expected millis: 253402300799 * 1000 + 999 = 253402300799999
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(max_ts))),
              Returns(Value(253402300799999LL)));
}

TEST_F(TimestampToUnixMillisTest, MinTimestampReturnsMillis) {
  // Min representable timestamp: seconds=-62135596800, nanos=0
  Timestamp min_ts(-62135596800LL, 0);
  // Expected millis: -62135596800 * 1000 = -62135596800000
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(min_ts))),
              Returns(Value(-62135596800000LL)));
}

TEST_F(TimestampToUnixMillisTest, TimestampTruncatesToMillis) {
  // Timestamp: seconds=-1, nanos=999999999
  // Millis: -1 * 1000 + 999 = -1
  Timestamp ts(-1, 999999999);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(ts))),
              Returns(Value(-1LL)));
}

TEST_F(TimestampToUnixMillisTest, TimestampOverflowReturnsError) {
  // Test with a timestamp whose millisecond equivalent would overflow int64_t.
  // Example: seconds slightly larger than INT64_MAX / 1000
  google_firestore_v1_Value timestamp_proto;
  // INT64_MAX is approx 9.22e18. INT64_MAX / 1000 is approx 9.22e15.
  timestamp_proto.timestamp_value.seconds =
      9223372036854776LL;  // > INT64_MAX / 1000
  timestamp_proto.timestamp_value.nanos = 0;
  timestamp_proto.which_value_type =
      google_firestore_v1_Value_timestamp_value_tag;

  EXPECT_THAT(
      EvaluateExpr(*TimestampToUnixMillisExpr(SharedConstant(timestamp_proto))),
      testutil::ReturnsError());
}

// Fixture for TimestampToUnixSeconds function tests
class TimestampToUnixSecondsTest : public TimestampExpressionsTest {};

using testutil::TimestampToUnixSecondsExpr;  // Add using declaration

TEST_F(TimestampToUnixSecondsTest, NonTimestampTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(123LL))),
              testutil::ReturnsError());
}

TEST_F(TimestampToUnixSecondsTest, TimestampReturnsSeconds) {
  Timestamp ts(347068800, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(ts))),
              Returns(Value(347068800LL)));
}

TEST_F(TimestampToUnixSecondsTest, EpochTimestampReturnsSeconds) {
  Timestamp ts(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(ts))),
              Returns(Value(0LL)));
}

TEST_F(TimestampToUnixSecondsTest, CurrentTimestampReturnsSeconds) {
  // Test with a known value
  Timestamp now(1678886400,
                123456789);  // Example: March 15, 2023 12:00:00.123456789 UTC
  int64_t expected_seconds = 1678886400LL;  // Truncates nanos
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(now))),
              Returns(Value(expected_seconds)));
}

TEST_F(TimestampToUnixSecondsTest, MaxTimestampReturnsSeconds) {
  // Max representable timestamp: seconds=253402300799, nanos=999999999
  Timestamp max_ts(253402300799LL, 999999999);
  // Expected seconds: 253402300799
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(max_ts))),
              Returns(Value(253402300799LL)));
}

TEST_F(TimestampToUnixSecondsTest, MinTimestampReturnsSeconds) {
  // Min representable timestamp: seconds=-62135596800, nanos=0
  Timestamp min_ts(-62135596800LL, 0);
  // Expected seconds: -62135596800
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(min_ts))),
              Returns(Value(-62135596800LL)));
}

TEST_F(TimestampToUnixSecondsTest, TimestampTruncatesToSeconds) {
  // Timestamp: seconds=-1, nanos=999999999
  // Seconds: -1
  Timestamp ts(-1, 999999999);
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(SharedConstant(ts))),
              Returns(Value(-1LL)));
}

TEST_F(TimestampToUnixSecondsTest, TimestampOverflowReturnsError) {
  google_firestore_v1_Value timestamp_proto_max;
  timestamp_proto_max.timestamp_value.seconds =
      std::numeric_limits<int64_t>::max();
  timestamp_proto_max.timestamp_value.nanos = 999999999;
  timestamp_proto_max.which_value_type =
      google_firestore_v1_Value_timestamp_value_tag;
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(
                  SharedConstant(timestamp_proto_max))),
              testutil::ReturnsError());

  google_firestore_v1_Value timestamp_proto_min;
  timestamp_proto_min.timestamp_value.seconds =
      std::numeric_limits<int64_t>::min();
  timestamp_proto_min.timestamp_value.nanos = 0;
  timestamp_proto_min.which_value_type =
      google_firestore_v1_Value_timestamp_value_tag;
  EXPECT_THAT(EvaluateExpr(*TimestampToUnixSecondsExpr(
                  SharedConstant(timestamp_proto_min))),
              testutil::ReturnsError());
}

// Fixture for TimestampAdd function tests
class TimestampAddTest : public TimestampExpressionsTest {};

using testutil::ReturnsNull;       // Add using declaration for null checks
using testutil::TimestampAddExpr;  // Add using declaration

TEST_F(TimestampAddTest, TimestampAddStringTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant("abc"),
                                             SharedConstant("second"),
                                             SharedConstant(1LL))),
              testutil::ReturnsError());
}

TEST_F(TimestampAddTest, TimestampAddZeroValueReturnsTimestampEpoch) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("second"),
                                             SharedConstant(0LL))),
              Returns(Value(epoch)));
}

TEST_F(TimestampAddTest, TimestampAddIntTypeReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("second"),
                                             SharedConstant(1LL))),
              Returns(Value(Timestamp(1, 0))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("second"),
                                             SharedConstant(9876543210LL))),
              Returns(Value(Timestamp(9876543210LL, 0))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeNegativeReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("second"),
                                             SharedConstant(-10000LL))),
              Returns(Value(Timestamp(-10000LL, 0))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeNegativeOverflowReturnsError) {
  Timestamp min_ts(-62135596800LL, 0);
  // Test adding 0 (boundary)
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(min_ts),
                                             SharedConstant("second"),
                                             SharedConstant(0LL))),
              Returns(Value(min_ts)));
  // Test adding -1 (overflow)
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(min_ts),
                                             SharedConstant("second"),
                                             SharedConstant(-1LL))),
              testutil::ReturnsError());
}

TEST_F(TimestampAddTest, TimestampAddLongTypePositiveOverflowReturnsError) {
  Timestamp max_ts(253402300799LL, 999999000);
  // Test adding 0 (boundary)
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(
                  SharedConstant(max_ts),
                  SharedConstant("microsecond"),  // Smallest unit
                  SharedConstant(0LL))),
              Returns(Value(max_ts)));  // Expect the same max timestamp

  // Test adding 1 microsecond (should overflow)
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(max_ts),
                                             SharedConstant("microsecond"),
                                             SharedConstant(1LL))),
              testutil::ReturnsError());

  // Test adding 1 second to a timestamp close to max
  Timestamp near_max_ts(253402300799LL, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(near_max_ts),
                                             SharedConstant("second"),
                                             SharedConstant(0LL))),
              Returns(Value(near_max_ts)));
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(near_max_ts),
                                             SharedConstant("second"),
                                             SharedConstant(1LL))),
              testutil::ReturnsError());
}

TEST_F(TimestampAddTest, TimestampAddLongTypeMinuteReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("minute"),
                                             SharedConstant(1LL))),
              Returns(Value(Timestamp(60, 0))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeHourReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(
      EvaluateExpr(*TimestampAddExpr(
          SharedConstant(epoch), SharedConstant("hour"), SharedConstant(1LL))),
      Returns(Value(Timestamp(3600, 0))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeDayReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(
      EvaluateExpr(*TimestampAddExpr(
          SharedConstant(epoch), SharedConstant("day"), SharedConstant(1LL))),
      Returns(Value(Timestamp(86400, 0))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeMillisecondReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("millisecond"),
                                             SharedConstant(1LL))),
              Returns(Value(Timestamp(0, 1000000))));
}

TEST_F(TimestampAddTest, TimestampAddLongTypeMicrosecondReturnsTimestamp) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("microsecond"),
                                             SharedConstant(1LL))),
              Returns(Value(Timestamp(0, 1000))));
}

TEST_F(TimestampAddTest, TimestampAddInvalidTimeUnitReturnsError) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(
      EvaluateExpr(*TimestampAddExpr(
          SharedConstant(epoch), SharedConstant("abc"), SharedConstant(1LL))),
      testutil::ReturnsError());
}

TEST_F(TimestampAddTest, TimestampAddInvalidAmountReturnsError) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("second"),
                                             SharedConstant("abc"))),
              testutil::ReturnsError());
}

TEST_F(TimestampAddTest, TimestampAddNullAmountReturnsNull) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(epoch),
                                             SharedConstant("second"),
                                             SharedConstant(nullptr))),
              ReturnsNull());
}

TEST_F(TimestampAddTest, TimestampAddNullTimeUnitReturnsNull) {
  Timestamp epoch(0, 0);
  EXPECT_THAT(
      EvaluateExpr(*TimestampAddExpr(
          SharedConstant(epoch), SharedConstant(nullptr), SharedConstant(1LL))),
      ReturnsNull());
}

TEST_F(TimestampAddTest, TimestampAddNullTimestampReturnsNull) {
  EXPECT_THAT(EvaluateExpr(*TimestampAddExpr(SharedConstant(nullptr),
                                             SharedConstant("second"),
                                             SharedConstant(1LL))),
              ReturnsNull());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

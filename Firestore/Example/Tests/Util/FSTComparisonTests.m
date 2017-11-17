/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Util/FSTComparison.h"

#import <XCTest/XCTest.h>

union DoubleBits {
  double d;
  uint64_t bits;
};

#define ASSERT_BIT_EQUALS(expected, actual)                                                       \
  do {                                                                                            \
    union DoubleBits expectedBits = {.d = expected};                                              \
    union DoubleBits actualBits = {.d = expected};                                                \
    if (expectedBits.bits != actualBits.bits) {                                                   \
      XCTFail(@"Expected <%f> to compare equal to <%f> with bits <%llX> equal to <%llX>", actual, \
              expected, actualBits.bits, expectedBits.bits);                                      \
    }                                                                                             \
  } while (0);

#define ASSERT_ORDERED_SAME(doubleValue, longValue)                                 \
  do {                                                                              \
    NSComparisonResult result = FSTCompareMixed(doubleValue, longValue);            \
    if (result != NSOrderedSame) {                                                  \
      XCTFail(@"Expected <%f> to compare equal to <%lld>", doubleValue, longValue); \
    }                                                                               \
  } while (0);

#define ASSERT_ORDERED_DESCENDING(doubleValue, longValue)                           \
  do {                                                                              \
    NSComparisonResult result = FSTCompareMixed(doubleValue, longValue);            \
    if (result != NSOrderedDescending) {                                            \
      XCTFail(@"Expected <%f> to compare equal to <%lld>", doubleValue, longValue); \
    }                                                                               \
  } while (0);

#define ASSERT_ORDERED_ASCENDING(doubleValue, longValue)                            \
  do {                                                                              \
    NSComparisonResult result = FSTCompareMixed(doubleValue, longValue);            \
    if (result != NSOrderedAscending) {                                             \
      XCTFail(@"Expected <%f> to compare equal to <%lld>", doubleValue, longValue); \
    }                                                                               \
  } while (0);

@interface FSTComparisonTests : XCTestCase
@end

@implementation FSTComparisonTests

- (void)testMixedComparison {
  // Infinities
  ASSERT_ORDERED_ASCENDING(-INFINITY, LLONG_MIN);
  ASSERT_ORDERED_ASCENDING(-INFINITY, LLONG_MAX);
  ASSERT_ORDERED_ASCENDING(-INFINITY, 0LL);

  ASSERT_ORDERED_DESCENDING(INFINITY, LLONG_MIN);
  ASSERT_ORDERED_DESCENDING(INFINITY, LLONG_MAX);
  ASSERT_ORDERED_DESCENDING(INFINITY, 0LL);

  // NaN
  ASSERT_ORDERED_ASCENDING(NAN, LLONG_MIN);
  ASSERT_ORDERED_ASCENDING(NAN, LLONG_MAX);
  ASSERT_ORDERED_ASCENDING(NAN, 0LL);

  // Large values (note DBL_MIN is positive and near zero).
  ASSERT_ORDERED_ASCENDING(-DBL_MAX, LLONG_MIN);

  // Tests around LLONG_MIN
  ASSERT_BIT_EQUALS((double)LLONG_MIN, -0x1.0p63);
  ASSERT_ORDERED_SAME(-0x1.0p63, LLONG_MIN);
  ASSERT_ORDERED_ASCENDING(-0x1.0p63, LLONG_MIN + 1);

  XCTAssertLessThan(-0x1.0000000000001p63, -0x1.0p63);
  ASSERT_ORDERED_ASCENDING(-0x1.0000000000001p63, LLONG_MIN);
  ASSERT_ORDERED_DESCENDING(-0x1.FFFFFFFFFFFFFp62, LLONG_MIN);

  // Tests around LLONG_MAX
  // Note LLONG_MAX cannot be exactly represented by a double, so the system rounds it to the
  // nearest double, which is 2^63. This number, in turn is larger than the maximum representable
  // as a long.
  ASSERT_BIT_EQUALS(0x1.0p63, (double)LLONG_MAX);
  ASSERT_ORDERED_DESCENDING(0x1.0p63, LLONG_MAX);

  // The largest value with an exactly long representation
  XCTAssertEqual((long)0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFC00LL);
  ASSERT_ORDERED_SAME(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFC00LL);

  ASSERT_ORDERED_DESCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFB00LL);
  ASSERT_ORDERED_DESCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFBFFLL);
  ASSERT_ORDERED_ASCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFC01LL);
  ASSERT_ORDERED_ASCENDING(0x1.FFFFFFFFFFFFFp62, 0x7FFFFFFFFFFFFD00LL);

  ASSERT_ORDERED_ASCENDING(0x1.FFFFFFFFFFFFEp62, 0x7FFFFFFFFFFFFC00LL);

  // Tests around MAX_SAFE_INTEGER
  ASSERT_ORDERED_SAME(0x1.FFFFFFFFFFFFFp52, 0x1FFFFFFFFFFFFFLL);
  ASSERT_ORDERED_DESCENDING(0x1.FFFFFFFFFFFFFp52, 0x1FFFFFFFFFFFFELL);
  ASSERT_ORDERED_ASCENDING(0x1.FFFFFFFFFFFFEp52, 0x1FFFFFFFFFFFFFLL);
  ASSERT_ORDERED_ASCENDING(0x1.FFFFFFFFFFFFFp52, 0x20000000000000LL);

  // Tests around MIN_SAFE_INTEGER
  ASSERT_ORDERED_SAME(-0x1.FFFFFFFFFFFFFp52, -0x1FFFFFFFFFFFFFLL);
  ASSERT_ORDERED_ASCENDING(-0x1.FFFFFFFFFFFFFp52, -0x1FFFFFFFFFFFFELL);
  ASSERT_ORDERED_DESCENDING(-0x1.FFFFFFFFFFFFEp52, -0x1FFFFFFFFFFFFFLL);
  ASSERT_ORDERED_DESCENDING(-0x1.FFFFFFFFFFFFFp52, -0x20000000000000LL);

  // Tests around zero.
  ASSERT_ORDERED_SAME(-0.0, 0LL);
  ASSERT_ORDERED_SAME(0.0, 0LL);

  // The smallest representable positive value should be greater than zero
  ASSERT_ORDERED_DESCENDING(DBL_MIN, 0LL);
  ASSERT_ORDERED_ASCENDING(-DBL_MIN, 0LL);

  // Note that 0x1.0p-1074 is a hex floating point literal representing the minimum subnormal
  // number: <https://en.wikipedia.org/wiki/Denormal_number>.
  double minSubNormal = 0x1.0p-1074;
  ASSERT_ORDERED_DESCENDING(minSubNormal, 0LL);
  ASSERT_ORDERED_ASCENDING(-minSubNormal, 0LL);

  // Other sanity checks
  ASSERT_ORDERED_ASCENDING(0.5, 1LL);
  ASSERT_ORDERED_DESCENDING(0.5, 0LL);
  ASSERT_ORDERED_ASCENDING(1.5, 2LL);
  ASSERT_ORDERED_DESCENDING(1.5, 1LL);
}

@end

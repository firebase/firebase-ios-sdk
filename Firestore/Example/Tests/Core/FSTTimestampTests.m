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

#import "Core/FSTTimestamp.h"

#import <XCTest/XCTest.h>

#import "Util/FSTAssert.h"

#import "FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTTimestampTests : XCTestCase
@end

@implementation FSTTimestampTests

- (void)testFromDate {
  // Very carefully construct an NSDate that won't lose precision with its milliseconds.
  NSDate *input = [NSDate dateWithTimeIntervalSinceReferenceDate:1.5];

  FSTTimestamp *actual = [FSTTimestamp timestampWithDate:input];
  static const int64_t kSecondsFromEpochToReferenceDate = 978307200;
  XCTAssertEqual(kSecondsFromEpochToReferenceDate + 1, actual.seconds);
  XCTAssertEqual(500000000, actual.nanos);

  FSTTimestamp *expected =
      [[FSTTimestamp alloc] initWithSeconds:(kSecondsFromEpochToReferenceDate + 1) nanos:500000000];
  XCTAssertEqualObjects(expected, actual);
}

- (void)testSO8601String {
  NSDate *date = FSTTestDate(1912, 4, 14, 23, 40, 0);
  FSTTimestamp *timestamp =
      [[FSTTimestamp alloc] initWithSeconds:(int64_t)date.timeIntervalSince1970 nanos:543000000];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1912-04-14T23:40:00.543000000Z");
}

- (void)testISO8601String_withLowMilliseconds {
  NSDate *date = FSTTestDate(1912, 4, 14, 23, 40, 0);
  FSTTimestamp *timestamp =
      [[FSTTimestamp alloc] initWithSeconds:(int64_t)date.timeIntervalSince1970 nanos:7000000];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1912-04-14T23:40:00.007000000Z");
}

- (void)testISO8601String_withLowNanos {
  FSTTimestamp *timestamp = [[FSTTimestamp alloc] initWithSeconds:0 nanos:1];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1970-01-01T00:00:00.000000001Z");
}

- (void)testISO8601String_withNegativeSeconds {
  FSTTimestamp *timestamp = [[FSTTimestamp alloc] initWithSeconds:-1 nanos:999999999];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1969-12-31T23:59:59.999999999Z");
}

- (void)testCompare {
  NSArray<FSTTimestamp *> *timestamps = @[
    [[FSTTimestamp alloc] initWithSeconds:12344 nanos:999999999],
    [[FSTTimestamp alloc] initWithSeconds:12345 nanos:0],
    [[FSTTimestamp alloc] initWithSeconds:12345 nanos:000000001],
    [[FSTTimestamp alloc] initWithSeconds:12345 nanos:99999999],
    [[FSTTimestamp alloc] initWithSeconds:12345 nanos:100000000],
    [[FSTTimestamp alloc] initWithSeconds:12345 nanos:100000001],
    [[FSTTimestamp alloc] initWithSeconds:12346 nanos:0],
  ];
  for (int i = 0; i < timestamps.count - 1; ++i) {
    XCTAssertEqual(NSOrderedAscending, [timestamps[i] compare:timestamps[i + 1]]);
    XCTAssertEqual(NSOrderedDescending, [timestamps[i + 1] compare:timestamps[i]]);
  }
}

@end

NS_ASSUME_NONNULL_END

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

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/FIRTimestampInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRTimestampTest : XCTestCase
@end

NSDate *TestDate(int year, int month, int day, int hour, int minute, int second) {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  comps.year = year;
  comps.month = month;
  comps.day = day;
  comps.hour = hour;
  comps.minute = minute;
  comps.second = second;
  // Force time zone to UTC to avoid these values changing due to daylight saving.
  comps.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

  return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

@implementation FIRTimestampTest

- (void)testFromDate {
  // Use an NSDate such that its fractional seconds have an exact representation to avoid losing
  // precision.
  NSDate *input = [NSDate dateWithTimeIntervalSinceReferenceDate:1.5];

  FIRTimestamp *actual = [FIRTimestamp timestampWithDate:input];
  static const int64_t kSecondsFromEpochToReferenceDate = 978307200;
  XCTAssertEqual(kSecondsFromEpochToReferenceDate + 1, actual.seconds);
  XCTAssertEqual(actual.nanoseconds, 500000000);

  FIRTimestamp *expected =
      [[FIRTimestamp alloc] initWithSeconds:(kSecondsFromEpochToReferenceDate + 1)
                                nanoseconds:500000000];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testSO8601String {
  NSDate *date = TestDate(1912, 4, 14, 23, 40, 0);
  FIRTimestamp *timestamp =
      [[FIRTimestamp alloc] initWithSeconds:(int64_t)date.timeIntervalSince1970
                                nanoseconds:543000000];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1912-04-14T23:40:00.543000000Z");
}

- (void)testISO8601String_withLowMilliseconds {
  NSDate *date = TestDate(1912, 4, 14, 23, 40, 0);
  FIRTimestamp *timestamp =
      [[FIRTimestamp alloc] initWithSeconds:(int64_t)date.timeIntervalSince1970
                                nanoseconds:7000000];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1912-04-14T23:40:00.007000000Z");
}

- (void)testISO8601String_withLowNanos {
  FIRTimestamp *timestamp = [[FIRTimestamp alloc] initWithSeconds:0 nanoseconds:1];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1970-01-01T00:00:00.000000001Z");
}

- (void)testISO8601String_withNegativeSeconds {
  FIRTimestamp *timestamp = [[FIRTimestamp alloc] initWithSeconds:-1 nanoseconds:999999999];
  XCTAssertEqualObjects(timestamp.ISO8601String, @"1969-12-31T23:59:59.999999999Z");
}

- (void)testCompare {
  NSArray<FIRTimestamp *> *timestamps = @[
    [[FIRTimestamp alloc] initWithSeconds:12344 nanoseconds:999999999],
    [[FIRTimestamp alloc] initWithSeconds:12345 nanoseconds:0],
    [[FIRTimestamp alloc] initWithSeconds:12345 nanoseconds:000000001],
    [[FIRTimestamp alloc] initWithSeconds:12345 nanoseconds:99999999],
    [[FIRTimestamp alloc] initWithSeconds:12345 nanoseconds:100000000],
    [[FIRTimestamp alloc] initWithSeconds:12345 nanoseconds:100000001],
    [[FIRTimestamp alloc] initWithSeconds:12346 nanoseconds:0],
  ];
  for (NSUInteger i = 0; i < timestamps.count - 1; ++i) {
    XCTAssertEqual([timestamps[i] compare:timestamps[i + 1]], NSOrderedAscending);
    XCTAssertEqual([timestamps[i + 1] compare:timestamps[i]], NSOrderedDescending);
  }
}

@end

NS_ASSUME_NONNULL_END

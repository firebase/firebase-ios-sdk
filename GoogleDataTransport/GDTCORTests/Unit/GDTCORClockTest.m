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

#import "GoogleDataTransport/GDTCORTests/Unit/GDTCORTestCase.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORClock.h"

@interface GDTCORClockTest : GDTCORTestCase

@end

@implementation GDTCORClockTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCORClockTest alloc] init]);
}

/** Tests taking a snapshot. */
- (void)testSnapshot {
  GDTCORClock *snapshot;
  XCTAssertNoThrow(snapshot = [GDTCORClock snapshot]);
  XCTAssertGreaterThan(snapshot.timeMillis, 0);
}

/** Tests that the hash of two snapshots right after each other isn't equal. */
- (void)testHash {
  GDTCORClock *snapshot1 = [GDTCORClock snapshot];
  GDTCORClock *snapshot2 = [GDTCORClock snapshot];
  XCTAssertNotEqual([snapshot1 hash], [snapshot2 hash]);
}

/** Tests that the class supports NSSecureEncoding. */
- (void)testSupportsSecureEncoding {
  XCTAssertTrue([GDTCORClock supportsSecureCoding]);
}

/** Tests encoding and decoding a clock using a keyed archiver. */
- (void)testEncoding {
  GDTCORClock *clock = [GDTCORClock snapshot];
  NSError *error;
  NSData *clockData = GDTCOREncodeArchive(clock, nil, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(clockData);

  error = nil;
  GDTCORClock *unarchivedClock =
      (GDTCORClock *)GDTCORDecodeArchive([GDTCORClock class], nil, clockData, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(unarchivedClock);
  XCTAssertEqual([clock hash], [unarchivedClock hash]);
  XCTAssertEqualObjects(clock, unarchivedClock);
}

/** Tests creating a clock that represents a future time. */
- (void)testClockSnapshotInTheFuture {
  GDTCORClock *clock1 = [GDTCORClock snapshot];
  GDTCORClock *clock2 = [GDTCORClock clockSnapshotInTheFuture:1];
  XCTAssertTrue([clock2 isAfter:clock1]);
}

/** Tests creating a snapshot in the future and comparing using isAfter: */
- (void)testIsAfter {
  GDTCORClock *clock1 = [GDTCORClock clockSnapshotInTheFuture:123456];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
  GDTCORClock *clock2 = [GDTCORClock snapshot];
  XCTAssertFalse([clock2 isAfter:clock1]);
}

- (void)testUptime {
  NSTimeInterval timeDiff = 1;
  GDTCORClock *clock1 = [GDTCORClock snapshot];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeDiff]];
  GDTCORClock *clock2 = [GDTCORClock snapshot];

  XCTAssertGreaterThan(clock2.uptimeNanoseconds, clock1.uptimeNanoseconds);
  NSTimeInterval uptimeDiff =
      (clock2.uptimeNanoseconds - clock1.uptimeNanoseconds) / (double)NSEC_PER_SEC;
  NSTimeInterval accuracy = 0.2;

  // Assert that uptime difference reflects the actually passed time.
  XCTAssertLessThanOrEqual(ABS(uptimeDiff - timeDiff), accuracy);
}

- (void)testUptimeMilliseconds {
  NSTimeInterval timeDiff = 1;
  GDTCORClock *clock1 = [GDTCORClock snapshot];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeDiff]];
  GDTCORClock *clock2 = [GDTCORClock snapshot];

  XCTAssertGreaterThan(clock2.uptimeNanoseconds, clock1.uptimeNanoseconds);

  NSTimeInterval millisecondsPerSecond = 1000;
  NSTimeInterval uptimeDiff =
      ([clock2 uptimeMilliseconds] - [clock1 uptimeMilliseconds]) / millisecondsPerSecond;
  NSTimeInterval accuracy = 0.2;

  // Assert that uptime difference reflects the actually passed time.
  XCTAssertLessThanOrEqual(ABS(uptimeDiff - timeDiff), accuracy);
}

- (void)testTimezoneOffsetSeconds {
  GDTCORClock *snapshot = [GDTCORClock snapshot];
  int64_t expectedTimeZoneOffset = [[NSTimeZone systemTimeZone] secondsFromGMT];
  XCTAssertEqual(snapshot.timezoneOffsetSeconds, expectedTimeZoneOffset);
}

@end

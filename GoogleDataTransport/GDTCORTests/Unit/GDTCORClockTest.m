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

#import "GDTCORTests/Unit/GDTCORTestCase.h"

#import "GDTCORLibrary/Public/GDTCORClock.h"

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
  GDTCORClock *unarchivedClock;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    NSData *clockData = [NSKeyedArchiver archivedDataWithRootObject:clock
                                              requiringSecureCoding:YES
                                                              error:nil];
    unarchivedClock = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTCORClock class]
                                                        fromData:clockData
                                                           error:nil];
  } else {
#if !TARGET_OS_MACCATALYST
    NSData *clockData = [NSKeyedArchiver archivedDataWithRootObject:clock];
    unarchivedClock = [NSKeyedUnarchiver unarchiveObjectWithData:clockData];
#endif
  }
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

@end

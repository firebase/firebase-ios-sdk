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

#import "GDTTests/Unit/GDTTestCase.h"

#import "GDTLibrary/Public/GDTClock.h"

@interface GDTClockTest : GDTTestCase

@end

@implementation GDTClockTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTClockTest alloc] init]);
}

/** Tests taking a snapshot. */
- (void)testSnapshot {
  GDTClock *snapshot;
  XCTAssertNoThrow(snapshot = [GDTClock snapshot]);
  XCTAssertGreaterThan(snapshot.timeMillis, 0);
}

/** Tests that the hash of two snapshots right after each other isn't equal. */
- (void)testHash {
  GDTClock *snapshot1 = [GDTClock snapshot];
  GDTClock *snapshot2 = [GDTClock snapshot];
  XCTAssertNotEqual([snapshot1 hash], [snapshot2 hash]);
}

/** Tests that the class supports NSSecureEncoding. */
- (void)testSupportsSecureEncoding {
  XCTAssertTrue([GDTClock supportsSecureCoding]);
}

/** Tests encoding and decoding a clock using a keyed archiver. */
- (void)testEncoding {
  GDTClock *clock = [GDTClock snapshot];
  GDTClock *unarchivedClock;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    NSData *clockData = [NSKeyedArchiver archivedDataWithRootObject:clock
                                              requiringSecureCoding:YES
                                                              error:nil];
    unarchivedClock = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTClock class]
                                                        fromData:clockData
                                                           error:nil];
  } else {
#if !defined(TARGET_OS_MACCATALYST)
    NSData *clockData = [NSKeyedArchiver archivedDataWithRootObject:clock];
    unarchivedClock = [NSKeyedUnarchiver unarchiveObjectWithData:clockData];
#endif
  }
  XCTAssertEqual([clock hash], [unarchivedClock hash]);
  XCTAssertEqualObjects(clock, unarchivedClock);
}

/** Tests creating a clock that represents a future time. */
- (void)testClockSnapshotInTheFuture {
  GDTClock *clock1 = [GDTClock snapshot];
  GDTClock *clock2 = [GDTClock clockSnapshotInTheFuture:1];
  XCTAssertTrue([clock2 isAfter:clock1]);
}

/** Tests creating a snapshot in the future and comparing using isAfter: */
- (void)testIsAfter {
  GDTClock *clock1 = [GDTClock clockSnapshotInTheFuture:123456];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
  GDTClock *clock2 = [GDTClock snapshot];
  XCTAssertFalse([clock2 isAfter:clock1]);
}

@end

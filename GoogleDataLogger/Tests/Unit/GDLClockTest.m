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

#import "GDLTestCase.h"

#import "GDLClock.h"

@interface GDLClockTest : GDLTestCase

@end

@implementation GDLClockTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDLClockTest alloc] init]);
}

/** Tests taking a snapshot. */
- (void)testSnapshot {
  GDLClock *snapshot;
  XCTAssertNoThrow(snapshot = [GDLClock snapshot]);
  XCTAssertGreaterThan(snapshot.timeMillis, 0);
}

/** Tests that the hash of two snapshots right after each other isn't equal. */
- (void)testHash {
  GDLClock *snapshot1 = [GDLClock snapshot];
  GDLClock *snapshot2 = [GDLClock snapshot];
  XCTAssertNotEqual([snapshot1 hash], [snapshot2 hash]);
}

/** Tests that the class supports NSSecureEncoding. */
- (void)testSupportsSecureEncoding {
  XCTAssertTrue([GDLClock supportsSecureCoding]);
}

- (void)testEncoding {
  GDLClock *clock = [GDLClock snapshot];
  NSData *clockData = [NSKeyedArchiver archivedDataWithRootObject:clock];
  GDLClock *unarchivedClock = [NSKeyedUnarchiver unarchiveObjectWithData:clockData];
  XCTAssertEqual([clock hash], [unarchivedClock hash]);
  XCTAssertEqualObjects(clock, unarchivedClock);
}

- (void)testClockSnapshotInTheFuture {
  GDLClock *clock1 = [GDLClock snapshot];
  GDLClock *clock2 = [GDLClock clockSnapshotInTheFuture:1];
  XCTAssertTrue([clock2 isAfter:clock1]);
}

@end

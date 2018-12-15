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

#import <XCTest/XCTest.h>

#import "GDLLogEvent.h"

@interface GDLLogEventTest : XCTestCase

@end

@implementation GDLLogEventTest

/** Tests the designated initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDLLogEvent alloc] initWithLogMapID:@"1" logTarget:1]);
  XCTAssertThrows([[GDLLogEvent alloc] initWithLogMapID:@"" logTarget:1]);
}

/** Tests NSKeyedArchiver encoding and decoding. */
- (void)testArchiving {
  XCTAssertTrue([GDLLogEvent supportsSecureCoding]);
  GDLLogClockSnapshot clockSnapshot = {10, 100, 1000};
  GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"testID" logTarget:42];
  logEvent.extensionData = [@"someData" dataUsingEncoding:NSUTF8StringEncoding];
  logEvent.qosTier = GDLLogQoSTelemetry;
  logEvent.clockSnapshot = clockSnapshot;

  NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:logEvent];
  logEvent = nil;

  logEvent = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
  XCTAssertEqualObjects(logEvent.logMapID, @"testID");
  XCTAssertEqual(logEvent.logTarget, 42);
  XCTAssertEqualObjects(logEvent.extensionData,
                        [@"someData" dataUsingEncoding:NSUTF8StringEncoding]);
  XCTAssertEqual(logEvent.qosTier, GDLLogQoSTelemetry);
  XCTAssertEqual(logEvent.clockSnapshot.timeMillis, 10);
  XCTAssertEqual(logEvent.clockSnapshot.uptimeMillis, 100);
  XCTAssertEqual(logEvent.clockSnapshot.timezoneOffsetMillis, 1000);
}

@end

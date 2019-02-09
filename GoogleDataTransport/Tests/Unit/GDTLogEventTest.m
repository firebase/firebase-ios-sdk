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

#import "GDTTestCase.h"

#import <GoogleDataTransport/GDTLogEvent.h>

#import "GDTLogEvent_Private.h"

@interface GDTLogEventTest : GDTTestCase

@end

@implementation GDTLogEventTest

/** Tests the designated initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTLogEvent alloc] initWithLogMapID:@"1" logTarget:1]);
  XCTAssertThrows([[GDTLogEvent alloc] initWithLogMapID:@"" logTarget:1]);
}

/** Tests NSKeyedArchiver encoding and decoding. */
- (void)testArchiving {
  XCTAssertTrue([GDTLogEvent supportsSecureCoding]);
  GDTClock *clockSnapshot = [GDTClock snapshot];
  int64_t timeMillis = clockSnapshot.timeMillis;
  int64_t timezoneOffsetSeconds = clockSnapshot.timezoneOffsetSeconds;
  GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"testID" logTarget:42];
  logEvent.extensionBytes = [@"someData" dataUsingEncoding:NSUTF8StringEncoding];
  logEvent.qosTier = GDTLogQoSTelemetry;
  logEvent.clockSnapshot = clockSnapshot;

  NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:logEvent];

  // To ensure that all the objects being retained by the original logEvent are dealloc'd.
  logEvent = nil;

  GDTLogEvent *decodedLogEvent = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
  XCTAssertEqualObjects(decodedLogEvent.logMapID, @"testID");
  XCTAssertEqual(decodedLogEvent.logTarget, 42);
  XCTAssertEqualObjects(decodedLogEvent.extensionBytes,
                        [@"someData" dataUsingEncoding:NSUTF8StringEncoding]);
  XCTAssertEqual(decodedLogEvent.qosTier, GDTLogQoSTelemetry);
  XCTAssertEqual(decodedLogEvent.clockSnapshot.timeMillis, timeMillis);
  XCTAssertEqual(decodedLogEvent.clockSnapshot.timezoneOffsetSeconds, timezoneOffsetSeconds);
}

@end

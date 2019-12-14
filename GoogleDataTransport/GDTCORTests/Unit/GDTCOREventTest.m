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

#import <GoogleDataTransport/GDTCOREvent.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"

@interface GDTCOREventTest : GDTCORTestCase

@end

@implementation GDTCOREventTest

/** Tests the designated initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCOREvent alloc] initWithMappingID:@"1" target:1]);
  XCTAssertNil([[GDTCOREvent alloc] initWithMappingID:@"" target:1]);
}

/** Tests NSKeyedArchiver encoding and decoding. */
- (void)testArchiving {
  XCTAssertTrue([GDTCOREvent supportsSecureCoding]);
  GDTCORClock *clockSnapshot = [GDTCORClock snapshot];
  int64_t timeMillis = clockSnapshot.timeMillis;
  int64_t timezoneOffsetSeconds = clockSnapshot.timezoneOffsetSeconds;
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"testID" target:42];
  event.dataObjectTransportBytes = [@"someData" dataUsingEncoding:NSUTF8StringEncoding];
  event.qosTier = GDTCOREventQoSTelemetry;
  event.clockSnapshot = clockSnapshot;

  NSData *archiveData;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    archiveData = [NSKeyedArchiver archivedDataWithRootObject:event
                                        requiringSecureCoding:YES
                                                        error:nil];
  } else {
#if !TARGET_OS_MACCATALYST
    archiveData = [NSKeyedArchiver archivedDataWithRootObject:event];
#endif
  }
  // To ensure that all the objects being retained by the original event are dealloc'd.
  event = nil;
  GDTCOREvent *decodedEvent;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    decodedEvent = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTCOREvent class]
                                                     fromData:archiveData
                                                        error:nil];
  } else {
#if !TARGET_OS_MACCATALYST
    decodedEvent = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
#endif
  }
  XCTAssertEqualObjects(decodedEvent.mappingID, @"testID");
  XCTAssertEqual(decodedEvent.target, 42);
  XCTAssertEqualObjects(decodedEvent.dataObjectTransportBytes,
                        [@"someData" dataUsingEncoding:NSUTF8StringEncoding]);
  XCTAssertEqual(decodedEvent.qosTier, GDTCOREventQoSTelemetry);
  XCTAssertEqual(decodedEvent.clockSnapshot.timeMillis, timeMillis);
  XCTAssertEqual(decodedEvent.clockSnapshot.timezoneOffsetSeconds, timezoneOffsetSeconds);
}

@end

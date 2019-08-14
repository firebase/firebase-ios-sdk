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

#import <GoogleDataTransport/GDTEvent.h>

#import "GDTLibrary/Private/GDTEvent_Private.h"

@interface GDTEventTest : GDTTestCase

@end

@implementation GDTEventTest

/** Tests the designated initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTEvent alloc] initWithMappingID:@"1" target:1]);
  XCTAssertThrows([[GDTEvent alloc] initWithMappingID:@"" target:1]);
}

/** Tests NSKeyedArchiver encoding and decoding. */
- (void)testArchiving {
  XCTAssertTrue([GDTEvent supportsSecureCoding]);
  GDTClock *clockSnapshot = [GDTClock snapshot];
  int64_t timeMillis = clockSnapshot.timeMillis;
  int64_t timezoneOffsetSeconds = clockSnapshot.timezoneOffsetSeconds;
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"testID" target:42];
  event.dataObjectTransportBytes = [@"someData" dataUsingEncoding:NSUTF8StringEncoding];
  event.qosTier = GDTEventQoSTelemetry;
  event.clockSnapshot = clockSnapshot;

  NSData *archiveData;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    archiveData = [NSKeyedArchiver archivedDataWithRootObject:event
                                        requiringSecureCoding:YES
                                                        error:nil];
  } else {
#if !defined(TARGET_OS_MACCATALYST)
    archiveData = [NSKeyedArchiver archivedDataWithRootObject:event];
#endif
  }
  // To ensure that all the objects being retained by the original event are dealloc'd.
  event = nil;
  GDTEvent *decodedEvent;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    decodedEvent = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTEvent class]
                                                     fromData:archiveData
                                                        error:nil];
  } else {
#if !defined(TARGET_OS_MACCATALYST)
    decodedEvent = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
#endif
  }
  XCTAssertEqualObjects(decodedEvent.mappingID, @"testID");
  XCTAssertEqual(decodedEvent.target, 42);
  XCTAssertEqualObjects(decodedEvent.dataObjectTransportBytes,
                        [@"someData" dataUsingEncoding:NSUTF8StringEncoding]);
  XCTAssertEqual(decodedEvent.qosTier, GDTEventQoSTelemetry);
  XCTAssertEqual(decodedEvent.clockSnapshot.timeMillis, timeMillis);
  XCTAssertEqual(decodedEvent.clockSnapshot.timezoneOffsetSeconds, timezoneOffsetSeconds);
}

@end

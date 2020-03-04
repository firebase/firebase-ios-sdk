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

#import <GoogleDataTransport/GDTCORClock.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORTargets.h>

#import "GDTCORTests/Unit/GDTCORTestCase.h"
#import "GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"

@interface GDTCOREventTest : GDTCORTestCase

@end

@implementation GDTCOREventTest

/** Tests the designated initializer. */
- (void)testInit {
  XCTAssertGreaterThan(
      [[GDTCOREvent alloc] initWithMappingID:@"1" target:kGDTCORTargetTest].eventID.integerValue,
      0);
  XCTAssertNotNil([[GDTCOREvent alloc] initWithMappingID:@"1" target:kGDTCORTargetTest]);
  XCTAssertNil([[GDTCOREvent alloc] initWithMappingID:@"" target:kGDTCORTargetTest]);
}

/** Tests NSKeyedArchiver encoding and decoding. */
- (void)testArchiving {
  XCTAssertTrue([GDTCOREvent supportsSecureCoding]);
  GDTCORClock *clockSnapshot = [GDTCORClock snapshot];
  int64_t timeMillis = clockSnapshot.timeMillis;
  int64_t timezoneOffsetSeconds = clockSnapshot.timezoneOffsetSeconds;
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"testID" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"someData"];
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
  XCTAssertEqual(decodedEvent.target, kGDTCORTargetTest);
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"someData"];
  XCTAssertEqual(decodedEvent.qosTier, GDTCOREventQoSTelemetry);
  XCTAssertEqual(decodedEvent.clockSnapshot.timeMillis, timeMillis);
  XCTAssertEqual(decodedEvent.clockSnapshot.timezoneOffsetSeconds, timezoneOffsetSeconds);
}

/** Tests setting variables on a GDTCOREvent instance.*/
- (void)testSettingVariables {
  XCTAssertTrue([GDTCOREvent supportsSecureCoding]);
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"testing" target:kGDTCORTargetTest];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.qosTier = GDTCOREventQoSTelemetry;
  XCTAssertNotNil(event);
  XCTAssertNotNil(event.mappingID);
  XCTAssertNotNil(@(event.target));
  XCTAssertEqual(event.qosTier, GDTCOREventQoSTelemetry);
  XCTAssertNotNil(event.clockSnapshot);
  XCTAssertNil(event.customBytes);
}

/** Tests equality between GDTCOREvents. */
- (void)testIsEqualAndHash {
  GDTCOREvent *event1 = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:kGDTCORTargetTest];
  event1.eventID = @123;
  event1.clockSnapshot = [GDTCORClock snapshot];
  [event1.clockSnapshot setValue:@(1553534573010) forKeyPath:@"timeMillis"];
  [event1.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
  [event1.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
  [event1.clockSnapshot setValue:@(961141365197) forKeyPath:@"uptime"];
  event1.qosTier = GDTCOREventQosDefault;
  NSError *error1;
  event1.customBytes = [NSJSONSerialization dataWithJSONObject:@{@"customParam1" : @"aValue1"}
                                                       options:0
                                                         error:&error1];
  XCTAssertNil(error1);
  [event1 writeToURL:[NSURL fileURLWithPath:@"/tmp/fake.txt"] error:&error1];
  XCTAssertNil(error1);

  GDTCOREvent *event2 = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:kGDTCORTargetTest];
  event2.eventID = @123;
  event2.clockSnapshot = [GDTCORClock snapshot];
  [event2.clockSnapshot setValue:@(1553534573010) forKeyPath:@"timeMillis"];
  [event2.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
  [event2.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
  [event2.clockSnapshot setValue:@(961141365197) forKeyPath:@"uptime"];
  event2.qosTier = GDTCOREventQosDefault;
  NSError *error2;
  event2.customBytes = [NSJSONSerialization dataWithJSONObject:@{@"customParam1" : @"aValue1"}
                                                       options:0
                                                         error:&error2];
  XCTAssertNil(error2);
  [event2 writeToURL:[NSURL fileURLWithPath:@"/tmp/fake.txt"] error:&error2];
  XCTAssertNil(error2);

  XCTAssertEqual([event1 hash], [event2 hash]);
  XCTAssertEqualObjects(event1, event2);

  // This only really tests that changing the timezoneOffsetSeconds value causes a change in hash.
  [event2.clockSnapshot setValue:@(-25201) forKeyPath:@"timezoneOffsetSeconds"];

  XCTAssertNotEqual([event1 hash], [event2 hash]);
  XCTAssertNotEqualObjects(event1, event2);
}

- (void)testGenerateEventIDs {
  NSMutableSet *generatedValues = [[NSMutableSet alloc] init];
  for (int i = 1; i < 100000; i++) {
    NSNumber *eventID;
    XCTAssertNoThrow(eventID = [GDTCOREvent nextEventID]);
    XCTAssertFalse([generatedValues containsObject:eventID]);
    [generatedValues addObject:eventID];
  }
}

@end

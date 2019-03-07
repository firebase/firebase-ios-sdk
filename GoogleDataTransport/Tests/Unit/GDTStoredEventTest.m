/*
 * Copyright 2019 Google
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

#import <GoogleDataTransport/GDTClock.h>
#import <GoogleDataTransport/GDTStoredEvent.h>

@interface GDTStoredEventTest : GDTTestCase

@end

@implementation GDTStoredEventTest

/** Tests the default initializer. */
- (void)testInit {
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"testing" target:1];
  event.clockSnapshot = [GDTClock snapshot];
  GDTStoredEvent *storedEvent = [[GDTStoredEvent alloc] initWithFileURL:[NSURL URLWithString:@"1"]
                                                                  event:event];
  XCTAssertNotNil(storedEvent);
}

/** Tests encoding and decoding. */
- (void)testNSSecureCoding {
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"testing" target:1];
  event.clockSnapshot = [GDTClock snapshot];
  event.qosTier = GDTEventQoSTelemetry;
  GDTStoredEvent *storedEvent = [[GDTStoredEvent alloc] initWithFileURL:[NSURL URLWithString:@"1"]
                                                                  event:event];
  XCTAssertNotNil(storedEvent);
  XCTAssertNotNil(storedEvent.mappingID);
  XCTAssertNotNil(storedEvent.target);
  XCTAssertEqual(storedEvent.qosTier, GDTEventQoSTelemetry);
  XCTAssertNotNil(storedEvent.clockSnapshot);
  XCTAssertNil(storedEvent.customPrioritizationParams);
  XCTAssertNotNil(storedEvent.eventFileURL);
}
@end

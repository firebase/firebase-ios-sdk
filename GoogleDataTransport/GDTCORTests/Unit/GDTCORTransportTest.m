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
#import <GoogleDataTransport/GDTCORTransport.h>

#import "GDTCORLibrary/Private/GDTCORTransport_Private.h"

#import "GDTCORTests/Common/Fakes/GDTCORTransformerFake.h"
#import "GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

@interface GDTCORTransportTest : GDTCORTestCase

@end

@implementation GDTCORTransportTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCORTransport alloc] initWithMappingID:@"1" transformers:nil target:1]);
  XCTAssertNil([[GDTCORTransport alloc] initWithMappingID:@"" transformers:nil target:1]);
}

/** Tests sending a telemetry event. */
- (void)testSendTelemetryEvent {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1"
                                                             transformers:nil
                                                                   target:1];
  transport.transformerInstance = [[GDTCORTransformerFake alloc] init];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transport sendTelemetryEvent:event]);
}

/** Tests sending a data event. */
- (void)testSendDataEvent {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1"
                                                             transformers:nil
                                                                   target:1];
  transport.transformerInstance = [[GDTCORTransformerFake alloc] init];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transport sendDataEvent:event]);
}

@end

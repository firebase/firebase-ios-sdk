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
#import <GoogleDataTransport/GDTTransport.h>

#import "GDTLibrary/Private/GDTTransport_Private.h"

#import "GDTTests/Common/Fakes/GDTTransformerFake.h"
#import "GDTTests/Unit/Helpers/GDTDataObjectTesterClasses.h"

@interface GDTTransportTest : GDTTestCase

@end

@implementation GDTTransportTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTTransport alloc] initWithMappingID:@"1" transformers:nil target:1]);
  XCTAssertThrows([[GDTTransport alloc] initWithMappingID:@"" transformers:nil target:1]);
}

/** Tests sending a telemetry event. */
- (void)testSendTelemetryEvent {
  GDTTransport *transport = [[GDTTransport alloc] initWithMappingID:@"1" transformers:nil target:1];
  transport.transformerInstance = [[GDTTransformerFake alloc] init];
  GDTEvent *event = [transport eventForTransport];
  event.dataObject = [[GDTDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transport sendTelemetryEvent:event]);
}

/** Tests sending a data event. */
- (void)testSendDataEvent {
  GDTTransport *transport = [[GDTTransport alloc] initWithMappingID:@"1" transformers:nil target:1];
  transport.transformerInstance = [[GDTTransformerFake alloc] init];
  GDTEvent *event = [transport eventForTransport];
  event.dataObject = [[GDTDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transport sendDataEvent:event]);
}

@end

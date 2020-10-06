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

#import "GoogleDataTransport/GDTCORTests/Unit/GDTCORTestCase.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORTransport.h"

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORTransport_Private.h"

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORStorageFake.h"
#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORTransformerFake.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

@interface GDTCORTransportTest : GDTCORTestCase

@end

@implementation GDTCORTransportTest

- (void)setUp {
  [super setUp];
  [[GDTCORRegistrar sharedInstance] registerStorage:[[GDTCORStorageFake alloc] init]
                                             target:kGDTCORTargetTest];
}

- (void)tearDown {
  [super tearDown];
  [[GDTCORRegistrar sharedInstance] reset];
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCORTransport alloc] initWithMappingID:@"1"
                                                transformers:nil
                                                      target:kGDTCORTargetTest]);
  XCTAssertNil([[GDTCORTransport alloc] initWithMappingID:@""
                                             transformers:nil
                                                   target:kGDTCORTargetTest]);
}

/** Tests sending a telemetry event. */
- (void)testSendTelemetryEvent {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];
  transport.transformerInstance = [[GDTCORTransformerFake alloc] init];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([transport sendTelemetryEvent:event
                                      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                        XCTAssertTrue(wasWritten);
                                        XCTAssertNil(error);
                                        [writtenExpectation fulfill];
                                      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
}

/** Tests sending a data event. */
- (void)testSendDataEvent {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];
  transport.transformerInstance = [[GDTCORTransformerFake alloc] init];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([transport sendDataEvent:event
                                 onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                   XCTAssertTrue(wasWritten);
                                   XCTAssertNil(error);
                                   [writtenExpectation fulfill];
                                 }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
}

@end

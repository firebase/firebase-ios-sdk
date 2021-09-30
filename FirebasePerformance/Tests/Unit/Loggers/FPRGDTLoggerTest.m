// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/FPRNanoPbUtils.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogSampler.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger_Private.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter.h"

#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

#import <GoogleDataTransport/GoogleDataTransport.h>
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORTransport_Private.h"
#import "SharedTestUtilities/GDTCORTransportFake.h"

@interface FPRGDTLoggerTest : XCTestCase

/** Fll logger used to dispatch events to Fll using Google Data Transport. */
@property(nonatomic) FPRGDTLogger *logger;

/** A fake for the GDTCORTransport for FLL. */
@property(nonatomic) GDTCORTransportFake *transportFLLFake;

/** The log source for the FPRGDTLogger  to be used. */
@property(nonatomic) NSInteger logSource;

/** The target backend of the GDTCORTransport - FLL. */
@property(nonatomic) NSInteger targetFL;

@end

@implementation FPRGDTLoggerTest

- (void)setUp {
  [super setUp];
  self.logSource = 1;
  self.targetFL = kGDTCORTargetFLL;  // FLL

  self.logger = [[FPRGDTLogger alloc] initWithLogSource:self.logSource];
  self.logger.isSimulator = YES;

  // Set up for Fake logging.
  self.transportFLLFake =
      [[GDTCORTransportFake alloc] initWithMappingID:@(self.logSource).stringValue
                                        transformers:nil
                                              target:self.targetFL];

  self.logger.gdtfllTransport = self.transportFLLFake;
}

- (void)tearDown {
  [self.transportFLLFake reset];
  [super tearDown];
}

/** Tests the designated initializer. */
- (void)testInitWithLogSource {
  NSInteger randomLogSource = 1;

  FPRGDTLogger *logger = [[FPRGDTLogger alloc] initWithLogSource:randomLogSource];

  XCTAssertNotNil(logger);
  XCTAssertEqual(logger.logSource, randomLogSource);
  XCTAssertNotNil(logger.gdtfllTransport);
}

/** Tests the GDTLogger is generated with designated transformers. */
- (void)testInitWithTransformers {
  NSInteger randomLogSource = 1;
  FPRGDTLogger *logger = [[FPRGDTLogger alloc] initWithLogSource:randomLogSource];

  XCTAssertNotNil(logger);
  XCTAssertNotNil(logger.gdtfllTransport);

  // GDT logger tests
  XCTAssertEqual(logger.gdtfllTransport.transformers.count, 2);
  XCTAssertTrue(
      [logger.gdtfllTransport.transformers.firstObject isKindOfClass:[FPRGDTLogSampler class]]);
  XCTAssertTrue(
      [logger.gdtfllTransport.transformers.lastObject isKindOfClass:[FPRGDTRateLimiter class]]);
}

/** Validate all the required fields are set when logging an Event. */
- (void)testValidateEventFieldsToBeLogged {
  // Log the event.
  firebase_perf_v1_PerfMetric event = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event.application_info.app_instance_id = FPREncodeString(@"abc");
  [self.logger logEvent:event];

  // Note: Refer "dispatch_async issue" in "testLogMultipleEvents".
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportFLLFake logEvents];
    GDTCOREvent *gdtCorEvent = gdtCorEventArray.firstObject;

    // Validate that only 1 event is logged.
    XCTAssertEqual(gdtCorEventArray.count, 1);
    // Validate that the corresponding GDTEvent to be logged is not nil.
    XCTAssertNotNil(gdtCorEvent.dataObject);
    // Validate that the mapping ID is correctly associated.
    XCTAssertEqual(gdtCorEvent.mappingID, @(self.logSource).stringValue);
    // Validate that the target is correctly associated.
    XCTAssertEqual(gdtCorEvent.target, self.targetFL);
    // Validate that the QoS is set to GDTCOREventQoSFast in debug mode.
    XCTAssertEqual(gdtCorEvent.qosTier, GDTCOREventQoSFast);
  });
}

/** Validate that multiple events are logged correctly. */
- (void)testLogMultipleEvents {
  // Log the events.
  int logCount = 3;
  for (int i = 1; i <= logCount; i++) {
    NSString *traceName = [NSString stringWithFormat:@"t%d", i];
    firebase_perf_v1_PerfMetric event = [FPRTestUtils createRandomPerfMetric:traceName];
    event.application_info.app_instance_id = FPREncodeString(@"abc");
    [self.logger logEvent:event];
  }

  // Note: "dispatch_async issue"
  //
  // There's a race condition between we checking the logEvents property on the "transportFake"
  // and writing to that property using the "logEvent" method from the "logger" class
  // because we are dispatching that event in a "dispatch_async" queue.
  //
  // To mitigate this we want that block to finish executing, so we call "dispatch_sync"
  // on the same "queue" and perform all the validations inside that block.
  //
  // This is because it will block the current thread until all queued blocks are done.
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged events.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportFLLFake logEvents];

    // Validate that the count of logged events is what is expected.
    XCTAssertEqual(gdtCorEventArray.count, logCount);
  });
}

/** Validate events' QoS are set to GDTCOREventQoSFast when running in Simulator. */
- (void)testEventsSimulatorQoS {
  self.logger.isSimulator = YES;

  // Log the event.
  firebase_perf_v1_PerfMetric event = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event.application_info.app_instance_id = FPREncodeString(@"abc");
  [self.logger logEvent:event];

  // Note: Refer "dispatch_async issue" in "testLogMultipleEvents".
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportFLLFake logEvents];
    GDTCOREvent *gdtCorEvent = gdtCorEventArray.firstObject;

    // Validate that the QoS is set to GDTCOREventQoSFast.
    XCTAssertEqual(gdtCorEvent.qosTier, GDTCOREventQoSFast);
  });
}

/** Validate events' QoS are set to GDTCOREventQosDefault in actual device. */
- (void)testEventsRealDeviceQoS {
  self.logger.isSimulator = NO;

  // Log the event.
  firebase_perf_v1_PerfMetric event = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event.application_info.app_instance_id = FPREncodeString(@"abc");
  [self.logger logEvent:event];

  // Note: Refer "dispatch_async issue" in "testLogMultipleEvents".
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportFLLFake logEvents];
    GDTCOREvent *gdtCorEvent = gdtCorEventArray.firstObject;

    // Validate that the QoS is set to GDTCOREventQosDefault.
    XCTAssertEqual(gdtCorEvent.qosTier, GDTCOREventQosDefault);
  });
}

@end

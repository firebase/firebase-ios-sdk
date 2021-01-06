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

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTCCLogger.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTCCLogger_Private.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogSampler.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"
#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfigFlags.h"
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"

#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GoogleDataTransportInternal.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORTransport_Private.h"
#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORTransportFake.h"

#import "FirebasePerformance/ProtoSupport/PerfMetric.pbobjc.h"

@interface FPRGDTCCLoggerTest : XCTestCase

/** Clearcut logger used to dispatch events to Clearcut using Google Data Transport. */
@property(nonatomic) FPRGDTCCLogger *logger;

/** A fake for the GDTCORTransport for clearcut. */
@property(nonatomic) GDTCORTransportFake *transportCCTFake;

/** A fake for the GDTCORTransport for FLL. */
@property(nonatomic) GDTCORTransportFake *transportFLLFake;

/** The log source for the FPRGDTCCLogger  to be used. */
@property(nonatomic) NSInteger logSource;

/** The target backend of the GDTCORTransport - Clearcut. */
@property(nonatomic) NSInteger targetCCT;

/** The target backend of the GDTCORTransport - FLL. */
@property(nonatomic) NSInteger targetFL;

@end

@implementation FPRGDTCCLoggerTest

- (void)setUp {
  [super setUp];
  self.logSource = 1;
  self.targetCCT = kGDTCORTargetCCT;  // CCT
  self.targetFL = kGDTCORTargetFLL;   // FLL

  self.logger = [[FPRGDTCCLogger alloc] initWithLogSource:self.logSource];
  self.logger.isSimulator = YES;
  // Set up for Fake logging.
  self.transportCCTFake =
      [[GDTCORTransportFake alloc] initWithMappingID:@(self.logSource).stringValue
                                        transformers:nil
                                              target:self.targetCCT];

  self.transportFLLFake =
      [[GDTCORTransportFake alloc] initWithMappingID:@(self.logSource).stringValue
                                        transformers:nil
                                              target:self.targetFL];

  self.logger.gdtcctTransport = self.transportCCTFake;
  self.logger.gdtfllTransport = self.transportFLLFake;
}

- (void)tearDown {
  [self.transportCCTFake reset];
  [self.transportFLLFake reset];
  [super tearDown];
}

/** Tests the designated initializer. */
- (void)testInitWithLogSource {
  NSInteger randomLogSource = 1;

  FPRGDTCCLogger *logger = [[FPRGDTCCLogger alloc] initWithLogSource:randomLogSource];

  XCTAssertNotNil(logger);
  XCTAssertEqual(logger.logSource, randomLogSource);
  XCTAssertNotNil(logger.gdtcctTransport);
}

/** Tests the GDTCCLogger is generated with designated transformers. */
- (void)testInitWithTransformers {
  NSInteger randomLogSource = 1;
  FPRGDTCCLogger *logger = [[FPRGDTCCLogger alloc] initWithLogSource:randomLogSource];

  XCTAssertNotNil(logger);
  XCTAssertNotNil(logger.gdtcctTransport);
  XCTAssertNotNil(logger.gdtfllTransport);

  // Clearcut logger tests
  XCTAssertEqual(logger.gdtcctTransport.transformers.count, 2);
  XCTAssertTrue(
      [logger.gdtcctTransport.transformers.firstObject isKindOfClass:[FPRGDTLogSampler class]]);
  XCTAssertTrue(
      [logger.gdtcctTransport.transformers.lastObject isKindOfClass:[FPRGDTRateLimiter class]]);

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
  FPRMSGPerfMetric *event = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event.applicationInfo.appInstanceId = @"abc";
  [self.logger logEvent:event];

  // Note: Refer "dispatch_async issue" in "testLogMultipleEvents".
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportCCTFake logEvents];
    GDTCOREvent *gdtCorEvent = gdtCorEventArray.firstObject;

    // Validate that only 1 event is logged.
    XCTAssertEqual(gdtCorEventArray.count, 1);
    // Validate that the corresponding GDTEvent to be logged is not nil.
    XCTAssertNotNil(gdtCorEvent.dataObject);
    // Validate that the mapping ID is correctly associated.
    XCTAssertEqual(gdtCorEvent.mappingID, @(self.logSource).stringValue);
    // Validate that the target is correctly associated.
    XCTAssertEqual(gdtCorEvent.target, self.targetCCT);
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
    FPRMSGPerfMetric *event = [FPRTestUtils createRandomPerfMetric:traceName];
    event.applicationInfo.appInstanceId = @"abc";
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
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportCCTFake logEvents];

    // Validate that the count of logged events is what is expected.
    XCTAssertEqual(gdtCorEventArray.count, logCount);
  });
}

/** Validate events' QoS are set to GDTCOREventQoSFast when running in Simulator. */
- (void)testEventsSimulatorQoS {
  self.logger.isSimulator = YES;

  // Log the event.
  FPRMSGPerfMetric *event = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event.applicationInfo.appInstanceId = @"abc";
  [self.logger logEvent:event];

  // Note: Refer "dispatch_async issue" in "testLogMultipleEvents".
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportCCTFake logEvents];
    GDTCOREvent *gdtCorEvent = gdtCorEventArray.firstObject;

    // Validate that the QoS is set to GDTCOREventQoSFast.
    XCTAssertEqual(gdtCorEvent.qosTier, GDTCOREventQoSFast);
  });
}

/** Validate events' QoS are set to GDTCOREventQosDefault in actual device. */
- (void)testEventsRealDeviceQoS {
  self.logger.isSimulator = NO;

  // Log the event.
  FPRMSGPerfMetric *event = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event.applicationInfo.appInstanceId = @"abc";
  [self.logger logEvent:event];

  // Note: Refer "dispatch_async issue" in "testLogMultipleEvents".
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event.
    NSArray<GDTCOREvent *> *gdtCorEventArray = [self.transportCCTFake logEvents];
    GDTCOREvent *gdtCorEvent = gdtCorEventArray.firstObject;

    // Validate that the QoS is set to GDTCOREventQosDefault.
    XCTAssertEqual(gdtCorEvent.qosTier, GDTCOREventQosDefault);
  });
}

/** Validate if the events are dispatched to FLL if installation ID seed is smaller than
 * transport percentage. */
- (void)testEventDispatchedToFllWithInstallationIdSeedSeedSmallerThanTransportPercentage {
  self.logger.isSimulator = NO;

  // Initialize the configurations
  FPRFakeConfigurations *fakeConfigurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  // Set fakes to the configurations
  FPRFakeRemoteConfig *fakeRemoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRFakeRemoteConfigFlags *fakeConfigFlags =
      [[FPRFakeRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)fakeRemoteConfig];
  fakeConfigFlags.userDefaults = [[NSUserDefaults alloc] init];
  fakeConfigurations.remoteConfigFlags = fakeConfigFlags;
  self.logger.configurations = fakeConfigurations;

  // Condition (1): when FLL transport percentage = 60% (greater than installation seed)
  fakeConfigurations.fllTransportPercentageValue = 60.00;

  // Log 2 random Perf events
  FPRMSGPerfMetric *event1 = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event1.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  FPRMSGPerfMetric *event2 = [FPRTestUtils createRandomPerfMetric:@"t2"];
  event2.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  [self.logger logEvent:event1];
  [self.logger logEvent:event2];

  // Verify: that both events are logged to FLL
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event
    NSArray<GDTCOREvent *> *gdtCorFllEventArray = [self.transportFLLFake logEvents];
    NSArray<GDTCOREvent *> *gdtCorCCTEventArray = [self.transportCCTFake logEvents];

    XCTAssertTrue(gdtCorFllEventArray.count == 2);
    XCTAssertTrue(gdtCorCCTEventArray.count == 0);
  });
}

/** Validate if the events are not dispatched to FLL if installation ID seed is greater than
 * transport percentage. */
- (void)testEventDispatchedNotToFllWithInstallationIdGreaterThanTransportPercentage {
  self.logger.isSimulator = NO;

  // Initialize the configurations
  FPRFakeConfigurations *fakeConfigurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  // Set fakes to the configurations
  FPRFakeRemoteConfig *fakeRemoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRFakeRemoteConfigFlags *fakeConfigFlags =
      [[FPRFakeRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)fakeRemoteConfig];
  fakeConfigFlags.userDefaults = [[NSUserDefaults alloc] init];
  fakeConfigurations.remoteConfigFlags = fakeConfigFlags;
  self.logger.configurations = fakeConfigurations;

  // Condition (1): when FLL transport percentage = 50% (less that installation seed)
  fakeConfigurations.fllTransportPercentageValue = 50.00;

  // Log 2 random Perf events
  FPRMSGPerfMetric *event1 = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event1.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  FPRMSGPerfMetric *event2 = [FPRTestUtils createRandomPerfMetric:@"t2"];
  event2.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  [self.logger logEvent:event1];
  [self.logger logEvent:event2];

  // Verify: that both events are logged to Clearcut
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event
    NSArray<GDTCOREvent *> *gdtCorFllEventArray = [self.transportFLLFake logEvents];
    NSArray<GDTCOREvent *> *gdtCorCCTEventArray = [self.transportCCTFake logEvents];

    XCTAssertTrue(gdtCorFllEventArray.count == 0);
    XCTAssertTrue(gdtCorCCTEventArray.count == 2);
  });
}

/** Validate if the events are dispatched to FLL if installation ID seed equals to transport
 * percentage. */
- (void)testEventDispatchedToFllWithInstallationIdSeedEqualsToTransportPercentage {
  self.logger.isSimulator = NO;

  // Initialize the configurations
  FPRFakeConfigurations *fakeConfigurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  // Set fakes to the configurations
  FPRFakeRemoteConfig *fakeRemoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRFakeRemoteConfigFlags *fakeConfigFlags =
      [[FPRFakeRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)fakeRemoteConfig];
  fakeConfigFlags.userDefaults = [[NSUserDefaults alloc] init];
  fakeConfigurations.remoteConfigFlags = fakeConfigFlags;
  self.logger.configurations = fakeConfigurations;

  // Condition (1): when FLL transport percentage = 54% (equal to installation seed)
  fakeConfigurations.fllTransportPercentageValue = 54.00;

  // Log 2 random Perf events
  FPRMSGPerfMetric *event1 = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event1.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  FPRMSGPerfMetric *event2 = [FPRTestUtils createRandomPerfMetric:@"t2"];
  event2.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  [self.logger logEvent:event1];
  [self.logger logEvent:event2];

  // Verify: that both events are logged to FLL
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event
    NSArray<GDTCOREvent *> *gdtCorFllEventArray = [self.transportFLLFake logEvents];
    NSArray<GDTCOREvent *> *gdtCorCCTEventArray = [self.transportCCTFake logEvents];

    XCTAssertTrue(gdtCorFllEventArray.count == 2);
    XCTAssertTrue(gdtCorCCTEventArray.count == 0);
  });
}

/** Validate if the events are dispatched to FLL if installation transport percentage is set to
 * maximum. */
- (void)testEventDispatchedToFllWithMaxTransportPercentage {
  self.logger.isSimulator = NO;

  // Initialize the configurations
  FPRFakeConfigurations *fakeConfigurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  // Set fakes to the configurations
  FPRFakeRemoteConfig *fakeRemoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRFakeRemoteConfigFlags *fakeConfigFlags =
      [[FPRFakeRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)fakeRemoteConfig];
  fakeConfigFlags.userDefaults = [[NSUserDefaults alloc] init];
  fakeConfigurations.remoteConfigFlags = fakeConfigFlags;
  self.logger.configurations = fakeConfigurations;

  // Condition: when FLL transport percentage = 100% (maximum %age)
  fakeConfigurations.fllTransportPercentageValue = 100.00;

  // Log 2 random Perf events
  FPRMSGPerfMetric *event1 = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event1.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  FPRMSGPerfMetric *event2 = [FPRTestUtils createRandomPerfMetric:@"t2"];
  event2.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  [self.logger logEvent:event1];
  [self.logger logEvent:event2];

  // Verify: that both events are logged to FLL
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event
    NSArray<GDTCOREvent *> *gdtCorFllEventArray = [self.transportFLLFake logEvents];
    NSArray<GDTCOREvent *> *gdtCorCCTEventArray = [self.transportCCTFake logEvents];

    XCTAssertTrue(gdtCorFllEventArray.count == 2);
    XCTAssertTrue(gdtCorCCTEventArray.count == 0);
  });
}

/** Validate if the events are dispatched to FLL if installation transport percentage is set to
 * minimum. */
- (void)testEventDispatchedNotToFllWithMinTransportPercentage {
  self.logger.isSimulator = NO;

  // Initialize the configurations
  FPRFakeConfigurations *fakeConfigurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  // Set fakes to the configurations
  FPRFakeRemoteConfig *fakeRemoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRFakeRemoteConfigFlags *fakeConfigFlags =
      [[FPRFakeRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)fakeRemoteConfig];
  fakeConfigFlags.userDefaults = [[NSUserDefaults alloc] init];
  fakeConfigurations.remoteConfigFlags = fakeConfigFlags;
  self.logger.configurations = fakeConfigurations;

  // Condition: when FLL transport percentage = 0% (minimum %age)
  fakeConfigurations.fllTransportPercentageValue = 0.00;

  // Log 2 random Perf events
  FPRMSGPerfMetric *event1 = [FPRTestUtils createRandomPerfMetric:@"t1"];
  event1.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  FPRMSGPerfMetric *event2 = [FPRTestUtils createRandomPerfMetric:@"t2"];
  event2.applicationInfo.appInstanceId = @"abc";  // Installation ID seed of "abc" is 54.0.
  [self.logger logEvent:event1];
  [self.logger logEvent:event2];

  // Verify: that both events are logged to Clearcut
  dispatch_sync(self.logger.queue, ^{
    // Fetch the logged event
    NSArray<GDTCOREvent *> *gdtCorFllEventArray = [self.transportFLLFake logEvents];
    NSArray<GDTCOREvent *> *gdtCorCCTEventArray = [self.transportCCTFake logEvents];

    XCTAssertTrue(gdtCorFllEventArray.count == 0);
    XCTAssertTrue(gdtCorCCTEventArray.count == 2);
  });
}

@end

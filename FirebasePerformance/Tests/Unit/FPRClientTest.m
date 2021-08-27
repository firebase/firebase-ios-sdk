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
#import "FirebasePerformance/Sources/FPRClient+Private.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/FPRNanoPbUtils.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger_Private.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeInstallations.h"

#import <OCMock/OCMock.h>
#import "SharedTestUtilities/GDTCORTransportFake.h"

NSString *const kFPRMockInstallationId = @"mockId";

@interface FPRClientTest : FPRTestCase

/** Configuration which can be assigned as a fake object for event dispatch control. */
@property(nonatomic) FPRConfigurations *configurations;

/** Fireperf client object which can be used for fake object injection and assertion . */
@property(nonatomic) FPRClient *client;

@end

@implementation FPRClientTest

- (void)setUp {
  [super setUp];

  // Arrange installations object.
  FPRFakeInstallations *installations = [FPRFakeInstallations installations];
  self.client = [[FPRClient alloc] init];
  installations.identifier = kFPRMockInstallationId;
  self.client.installations = (FIRInstallations *)installations;

  // Arrange remote config object.
  FPRFakeConfigurations *fakeConfigs =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];
  self.configurations = fakeConfigs;
  fakeConfigs.dataCollectionEnabled = YES;
  fakeConfigs.sdkEnabled = YES;
  self.client.configuration = self.configurations;

  // Arrange gdtLogger object for event dispatch.
  self.client.gdtLogger = [[FPRGDTLogger alloc] initWithLogSource:1];
  GDTCORTransportFake *fakeGdtTransport =
      [[GDTCORTransportFake alloc] initWithMappingID:@"1" transformers:nil target:kGDTCORTargetFLL];
  self.client.gdtLogger.gdtfllTransport = fakeGdtTransport;
}

/** Validates if the gdtTransport logger has received trace perfMetric. */
- (void)testLogAndProcessEventsForTrace {
  // Trace type PerfMetric for event dispatch.
  firebase_perf_v1_PerfMetric perfMetric = [FPRTestUtils createRandomPerfMetric:@"RandomTrace"];

  // Act on event logging call.
  [self.client processAndLogEvent:perfMetric];

  firebase_perf_v1_PerfMetric expectedMetric = perfMetric;
  expectedMetric.application_info.app_instance_id = FPREncodeString(kFPRMockInstallationId);

  // Wait for async job to execute event logging.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  // Validate the event is received by gdtTransport logger.
  dispatch_sync(self.client.gdtLogger.queue, ^{
    GDTCORTransportFake *fakeGdtTransport =
        (GDTCORTransportFake *)self.client.gdtLogger.gdtfllTransport;
    XCTAssertEqual(fakeGdtTransport.logEvents.count, 1);
    GDTCOREvent *event = fakeGdtTransport.logEvents.firstObject;
    XCTAssertNotNil(
        FPRDecodeString([(FPRGDTEvent *)event.dataObject metric].application_info.app_instance_id));
    XCTAssertEqualObjects([event.dataObject transportBytes],
                          [[FPRGDTEvent gdtEventForPerfMetric:expectedMetric] transportBytes]);
  });
}

/** Validates if the gdtTransport logger has received network trace perfMetric. */
- (void)testLogAndProcessEventsForNetworkTrace {
  // Network type PerfMetric for event dispatch.
  firebase_perf_v1_PerfMetric perfMetric =
      [FPRTestUtils createRandomNetworkPerfMetric:@"https://abc.xyz"];

  // Act on event logging call.
  [self.client processAndLogEvent:perfMetric];

  firebase_perf_v1_PerfMetric expectedMetric = perfMetric;
  expectedMetric.application_info.app_instance_id = FPREncodeString(kFPRMockInstallationId);

  // Wait for async job to execute event logging.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  // Validate the event is received by gdtTransport logger.
  dispatch_sync(self.client.gdtLogger.queue, ^{
    GDTCORTransportFake *fakeGdtTransport =
        (GDTCORTransportFake *)self.client.gdtLogger.gdtfllTransport;
    XCTAssertEqual(fakeGdtTransport.logEvents.count, 1);
    GDTCOREvent *event = fakeGdtTransport.logEvents.firstObject;
    XCTAssertNotNil(
        FPRDecodeString([(FPRGDTEvent *)event.dataObject metric].application_info.app_instance_id));
    XCTAssertEqualObjects([event.dataObject transportBytes],
                          [[FPRGDTEvent gdtEventForPerfMetric:expectedMetric] transportBytes]);
  });
}

/** Validates if the gdtTransport logger has received session gauge perfMetric. */
- (void)testLogAndProcessEventsForGauge {
  // Gauge type PerfMetric for event dispatch.
  firebase_perf_v1_PerfMetric perfMetric = [FPRTestUtils createRandomGaugePerfMetric];

  // Act on event logging call.
  [self.client processAndLogEvent:perfMetric];

  firebase_perf_v1_PerfMetric expectedMetric = perfMetric;
  expectedMetric.application_info.app_instance_id = FPREncodeString(kFPRMockInstallationId);

  // Wait for async job to execute event logging.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  // Validate the event is received by gdtTransport logger.
  dispatch_sync(self.client.gdtLogger.queue, ^{
    GDTCORTransportFake *fakeGdtTransport =
        (GDTCORTransportFake *)self.client.gdtLogger.gdtfllTransport;
    XCTAssertEqual(fakeGdtTransport.logEvents.count, 1);
    GDTCOREvent *event = fakeGdtTransport.logEvents.firstObject;
    XCTAssertNotNil(
        FPRDecodeString([(FPRGDTEvent *)event.dataObject metric].application_info.app_instance_id));
    XCTAssertEqualObjects([event.dataObject transportBytes],
                          [[FPRGDTEvent gdtEventForPerfMetric:expectedMetric] transportBytes]);
  });
}

/** Validates if the gdtTransport logger will not receive event when data collection is disabled. */
- (void)testLogAndProcessEventsNotDispatchWhenDisabled {
  // Trace type PerfMetric for event dispatch.
  firebase_perf_v1_PerfMetric perfMetric = [FPRTestUtils createRandomPerfMetric:@"RandomTrace"];

  // Act on event logging call when data collection is disabled.
  self.configurations.dataCollectionEnabled = NO;
  [self.client processAndLogEvent:perfMetric];

  // Wait for async job to execute event logging.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  // Validate the event is not received by gdtTransport logger.
  dispatch_sync(self.client.gdtLogger.queue, ^{
    GDTCORTransportFake *fakeGdtTransport =
        (GDTCORTransportFake *)self.client.gdtLogger.gdtfllTransport;
    XCTAssertEqual(fakeGdtTransport.logEvents.count, 0);
  });
}

/** Validates if the gdtTransport logger will resume receiving event when data collection is
 * re-enabled. */
- (void)testLogAndProcessEventsAfterReenabled {
  // Trace type PerfMetric for event dispatch.
  firebase_perf_v1_PerfMetric perfMetric = [FPRTestUtils createRandomPerfMetric:@"RandomTrace"];

  // Act on event logging call when data collection is disabled.
  self.configurations.dataCollectionEnabled = NO;
  [self.client processAndLogEvent:perfMetric];

  // Wait for async job to execute event logging.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  // Validate the event is not received by gdtTransport logger.
  dispatch_sync(self.client.gdtLogger.queue, ^{
    GDTCORTransportFake *fakeGdtTransport =
        (GDTCORTransportFake *)self.client.gdtLogger.gdtfllTransport;
    XCTAssertEqual(fakeGdtTransport.logEvents.count, 0);
  });

  // Act on event logging call after re-enable data collection.
  self.configurations.dataCollectionEnabled = YES;
  [self.client processAndLogEvent:perfMetric];

  // Wait for async job to execute event logging.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  // Validate the event is received by gdtTransport logger.
  dispatch_sync(self.client.gdtLogger.queue, ^{
    GDTCORTransportFake *fakeGdtTransport =
        (GDTCORTransportFake *)self.client.gdtLogger.gdtfllTransport;
    XCTAssertEqual(fakeGdtTransport.logEvents.count, 1);
  });
}

/** Validates that the Clearcut log directory removal method is called. */
- (void)testClearcutLogDirectoryCleanupInitiates {
  id clientMock = OCMClassMock(self.client.class);
  [self.client startWithConfiguration:[[FPRConfiguration alloc] initWithAppID:@"RandomAppId"
                                                                       APIKey:nil
                                                                     autoPush:YES]
                                error:nil];

  // Wait for async job to initiate cleanup logic.
  dispatch_group_wait(self.client.eventsQueueGroup, DISPATCH_TIME_FOREVER);

  OCMVerify([clientMock cleanupClearcutCacheDirectory]);
}

/**
 * Validates that the log directory path in the cache directory created for Clearcut logs storage
 * gets removed (if exist).
 */
- (void)testValidateClearcutLogDirectoryCleanupIfExists {
  // Create the log directory and make sure it exists.
  NSString *logDirectoryPath = [FPRClient logDirectoryPath];
  [[NSFileManager defaultManager] createDirectoryAtPath:logDirectoryPath
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];

  BOOL logDirectoryExists = [[NSFileManager defaultManager] fileExistsAtPath:logDirectoryPath];
  XCTAssertTrue(logDirectoryExists);

  [FPRClient cleanupClearcutCacheDirectory];

  logDirectoryExists = [[NSFileManager defaultManager] fileExistsAtPath:logDirectoryPath];
  XCTAssertFalse(logDirectoryExists);
}

/**
 * Validates that the Clearcut log directory path removal logic doesn't explode if directory doesn't
 * exist.
 */
- (void)testValidateClearcutLogDirectoryCleanupIfNotExists {
  NSString *logDirectoryPath = [FPRClient logDirectoryPath];
  BOOL logDirectoryExists = [[NSFileManager defaultManager] fileExistsAtPath:logDirectoryPath];

  XCTAssertFalse(logDirectoryExists);
  XCTAssertNoThrow([FPRClient cleanupClearcutCacheDirectory]);
}

@end

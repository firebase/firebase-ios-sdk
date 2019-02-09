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

#import <XCTest/XCTest.h>

#import <GoogleDataTransport/GoogleDataTransport.h>

#import "GDTIntegrationTestPrioritizer.h"
#import "GDTIntegrationTestUploader.h"
#import "GDTTestServer.h"

#import "GDTLogStorage_Private.h"
#import "GDTUploadCoordinator+Testing.h"

/** A test-only log object used in this integration test. */
@interface GDTIntegrationTestLog : NSObject <GDTLogProto>

@end

@implementation GDTIntegrationTestLog

- (NSData *)transportBytes {
  // In real usage, protobuf's -data method or a custom implementation using nanopb are used.
  return [[NSString stringWithFormat:@"%@", [NSDate date]] dataUsingEncoding:NSUTF8StringEncoding];
}

@end

/** A test-only log transformer. */
@interface GDTIntegrationTestTransformer : NSObject <GDTLogTransformer>

@end

@implementation GDTIntegrationTestTransformer

- (GDTLogEvent *)transform:(GDTLogEvent *)logEvent {
  // drop half the logs during transforming.
  if (arc4random_uniform(2) == 1) {
    logEvent = nil;
  }
  return logEvent;
}

@end

@interface GDTIntegrationTest : XCTestCase

/** A test prioritizer. */
@property(nonatomic) GDTIntegrationTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDTIntegrationTestUploader *uploader;

/** The first test logger. */
@property(nonatomic) GDTLogger *logger1;

/** The second test logger. */
@property(nonatomic) GDTLogger *logger2;

@end

@implementation GDTIntegrationTest

- (void)tearDown {
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 0);
  });
}

- (void)testEndToEndLog {
  XCTestExpectation *expectation = [self expectationWithDescription:@"server got the request"];
  expectation.assertForOverFulfill = NO;

  // Create the server.
  GDTTestServer *testServer = [[GDTTestServer alloc] init];
  [testServer setResponseCompletedBlock:^(GCDWebServerRequest *_Nonnull request,
                                          GCDWebServerResponse *_Nonnull response) {
    [expectation fulfill];
  }];
  [testServer registerTestPaths];
  [testServer start];

  // Create loggers.
  self.logger1 = [[GDTLogger alloc] initWithLogMapID:@"logMap1"
                                     logTransformers:nil
                                           logTarget:kGDTIntegrationTestTarget];

  self.logger2 = [[GDTLogger alloc] initWithLogMapID:@"logMap2"
                                     logTransformers:nil
                                           logTarget:kGDTIntegrationTestTarget];

  // Create a prioritizer and uploader.
  self.prioritizer = [[GDTIntegrationTestPrioritizer alloc] init];
  self.uploader = [[GDTIntegrationTestUploader alloc] initWithServerURL:testServer.serverURL];

  // Set the interval to be much shorter than the standard timer.
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC * 0.1;
  [GDTUploadCoordinator sharedInstance].timerLeeway = NSEC_PER_SEC * 0.01;

  // Confirm no logs are in disk.
  XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 0);
  XCTAssertEqual([GDTLogStorage sharedInstance].logTargetToLogHashSet.count, 0);

  // Generate some logs data.
  [self generateLogs];

  // Confirm logs are on disk.
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertGreaterThan([GDTLogStorage sharedInstance].logHashToLogFile.count, 0);
    XCTAssertGreaterThan([GDTLogStorage sharedInstance].logTargetToLogHashSet.count, 0);
  });

  // Confirm logs were sent and received.
  [self waitForExpectations:@[ expectation ] timeout:10.0];

  // Generate logs for a bit.
  NSUInteger lengthOfTestToRunInSeconds = 30;
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC * 5;
  [GDTUploadCoordinator sharedInstance].timerLeeway = NSEC_PER_SEC * 1;
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
  dispatch_source_set_event_handler(timer, ^{
    static int numberOfTimesCalled = 0;
    numberOfTimesCalled++;
    if (numberOfTimesCalled < lengthOfTestToRunInSeconds) {
      [self generateLogs];
    } else {
      dispatch_source_cancel(timer);
    }
  });
  dispatch_resume(timer);

  // Run for a bit, a couple seconds longer than the previous bit.
  [[NSRunLoop currentRunLoop]
      runUntilDate:[NSDate dateWithTimeIntervalSinceNow:lengthOfTestToRunInSeconds + 2]];

  [testServer stop];
}

/** Generates and logs a bunch of random logs. */
- (void)generateLogs {
  for (int i = 0; i < 50; i++) {
    // Choose a random logger, and randomly choose if it's a telemetry log.
    GDTLogger *logger = arc4random_uniform(2) ? self.logger1 : self.logger2;
    BOOL isTelemetryLog = arc4random_uniform(2);

    // Create a log
    GDTLogEvent *logEvent = [logger newEvent];
    logEvent.extension = [[GDTIntegrationTestLog alloc] init];

    if (isTelemetryLog) {
      [logger logTelemetryEvent:logEvent];
    } else {
      [logger logDataEvent:logEvent];
    }
  }
}

@end

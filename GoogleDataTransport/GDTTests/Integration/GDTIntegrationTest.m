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

#import <GoogleDataTransport/GDTEvent.h>
#import <GoogleDataTransport/GDTEventDataObject.h>
#import <GoogleDataTransport/GDTEventTransformer.h>
#import <GoogleDataTransport/GDTTransport.h>

#import "GDTTests/Common/Categories/GDTUploadCoordinator+Testing.h"

#import "GDTTests/Integration/Helpers/GDTIntegrationTestPrioritizer.h"
#import "GDTTests/Integration/Helpers/GDTIntegrationTestUploader.h"
#import "GDTTests/Integration/TestServer/GDTTestServer.h"

#import "GDTLibrary/Private/GDTReachability_Private.h"
#import "GDTLibrary/Private/GDTStorage_Private.h"
#import "GDTLibrary/Private/GDTTransformer_Private.h"

/** A test-only event data object used in this integration test. */
@interface GDTIntegrationTestEvent : NSObject <GDTEventDataObject>

@end

@implementation GDTIntegrationTestEvent

- (NSData *)transportBytes {
  // In real usage, protobuf's -data method or a custom implementation using nanopb are used.
  return [[NSString stringWithFormat:@"%@", [NSDate date]] dataUsingEncoding:NSUTF8StringEncoding];
}

@end

/** A test-only event transformer. */
@interface GDTIntegrationTestTransformer : NSObject <GDTEventTransformer>

@end

@implementation GDTIntegrationTestTransformer

- (GDTEvent *)transform:(GDTEvent *)event {
  // drop half the events during transforming.
  if (arc4random_uniform(2) == 0) {
    event = nil;
  }
  return event;
}

@end

@interface GDTIntegrationTest : XCTestCase

/** A test prioritizer. */
@property(nonatomic) GDTIntegrationTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDTIntegrationTestUploader *uploader;

/** The first test transport. */
@property(nonatomic) GDTTransport *transport1;

/** The second test transport. */
@property(nonatomic) GDTTransport *transport2;

@end

@implementation GDTIntegrationTest

- (void)tearDown {
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
  });
}

- (void)testEndToEndEvent {
  XCTestExpectation *expectation = [self expectationWithDescription:@"server got the request"];
  expectation.assertForOverFulfill = NO;

  // Manually set the reachability flag.
  [GDTReachability sharedInstance].flags = kSCNetworkReachabilityFlagsReachable;

  // Create the server.
  GDTTestServer *testServer = [[GDTTestServer alloc] init];
  [testServer setResponseCompletedBlock:^(GCDWebServerRequest *_Nonnull request,
                                          GCDWebServerResponse *_Nonnull response) {
    [expectation fulfill];
  }];
  [testServer registerTestPaths];
  [testServer start];

  // Create eventgers.
  self.transport1 = [[GDTTransport alloc] initWithMappingID:@"eventMap1"
                                               transformers:nil
                                                     target:kGDTIntegrationTestTarget];

  self.transport2 =
      [[GDTTransport alloc] initWithMappingID:@"eventMap2"
                                 transformers:@[ [[GDTIntegrationTestTransformer alloc] init] ]
                                       target:kGDTIntegrationTestTarget];

  // Create a prioritizer and uploader.
  self.prioritizer = [[GDTIntegrationTestPrioritizer alloc] init];
  self.uploader = [[GDTIntegrationTestUploader alloc] initWithServerURL:testServer.serverURL];

  // Set the interval to be much shorter than the standard timer.
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC * 0.1;
  [GDTUploadCoordinator sharedInstance].timerLeeway = NSEC_PER_SEC * 0.01;

  // Confirm no events are in disk.
  XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
  XCTAssertEqual([GDTStorage sharedInstance].targetToEventSet.count, 0);

  // Generate some events data.
  [self generateEvents];

  // Flush the transformer queue.
  dispatch_sync([GDTTransformer sharedInstance].eventWritingQueue, ^{
                });

  // Confirm events are on disk.
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertGreaterThan([GDTStorage sharedInstance].storedEvents.count, 0);
    XCTAssertGreaterThan([GDTStorage sharedInstance].targetToEventSet.count, 0);
  });

  // Confirm events were sent and received.
  [self waitForExpectations:@[ expectation ] timeout:10.0];

  // Generate events for a bit.
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
      [self generateEvents];
    } else {
      dispatch_source_cancel(timer);
    }
  });
  dispatch_resume(timer);

  // Run for a bit, several seconds longer than the previous bit.
  [[NSRunLoop currentRunLoop]
      runUntilDate:[NSDate dateWithTimeIntervalSinceNow:lengthOfTestToRunInSeconds + 5]];

  [testServer stop];
}

/** Generates a bunch of random events. */
- (void)generateEvents {
  for (int i = 0; i < arc4random_uniform(10) + 1; i++) {
    // Choose a random transport, and randomly choose if it's a telemetry event.
    GDTTransport *transport = arc4random_uniform(2) ? self.transport1 : self.transport2;
    BOOL isTelemetryEvent = arc4random_uniform(2);

    // Create an event.
    GDTEvent *event = [transport eventForTransport];
    event.dataObject = [[GDTIntegrationTestEvent alloc] init];

    if (isTelemetryEvent) {
      [transport sendTelemetryEvent:event];
    } else {
      [transport sendDataEvent:event];
    }
  }
}

@end

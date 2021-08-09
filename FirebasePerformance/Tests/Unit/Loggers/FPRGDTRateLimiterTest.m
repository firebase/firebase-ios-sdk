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

#import "FirebasePerformance/Sources/Loggers/FPRGDTEvent.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter+Private.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter.h"

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRTrace.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Tests/Unit/Common/FPRFakeDate.h"
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

#import <GoogleDataTransport/GoogleDataTransport.h>

@interface FPRGDTRateLimiterTest : FPRTestCase

@end

@implementation FPRGDTRateLimiterTest

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
}

/** Validates that the object creation was successful and default values are correct. */
- (void)testInstanceCreation {
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] init];
  XCTAssertNotNil(transformer);
  if ([FPRAppActivityTracker sharedInstance].applicationState == FPRApplicationStateBackground) {
    XCTAssertEqual(transformer.allowedTraceEventsCount, 30);
    XCTAssertEqual(transformer.allowedNetworkEventsCount, 70);
  } else {
    XCTAssertEqual(transformer.allowedTraceEventsCount, 300);
    XCTAssertEqual(transformer.allowedNetworkEventsCount, 700);
  }
}

/** Validates the rate limiter allows sending valid events. */
- (void)testRateLimitingAlgorithmValidEvent {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];
  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomTraceGDTEvent:@"trace"];
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter allows sending valid network events. */
- (void)testRateLimitingAlgorithmValidNetworkRequestEvent {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];
  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomNetworkGDTEvent:@"https://abc.xyz"];
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter allows sending events and drops events when exceeds allowed events
 * count. */
- (void)testRateLimitingAlgorithmDropsEventsWhenExceedsAllowedEventsCount {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];

  // Set the rate limit to 60 events per minute.
  [transformer setOverrideRate:60];
  transformer.traceEventBurstSize = 100;
  transformer.allowedTraceEventsCount = 0;

  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomTraceGDTEvent:@"trace"];

  transformer.lastTraceEventTime = fakeDate.now;
  [fakeDate incrementTime:1];

  // Send an event to see if that event is accepted.
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);

  // Ensure that the event is dropped as we have reached allowed events count.
  XCTAssertNil([transformer transformGDTEvent:gdtEvent]);

  // Events should be accepted after few seconds.
  transformer.lastTraceEventTime = fakeDate.now;
  [fakeDate incrementTime:1];
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter does not apply on internal traces even when exceeds allowed events
 * count. */
- (void)testRateLimitingAlgorithmDoesNotSkipInternalTracesWhenExceedsAllowedEventsCount {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];

  // Set the rate limit to 60 events per minute.
  [transformer setOverrideRate:60];
  transformer.traceEventBurstSize = 100;
  transformer.allowedTraceEventsCount = 0;

  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomInternalTraceGDTEvent:@"internal_trace"];

  transformer.lastTraceEventTime = fakeDate.now;
  [fakeDate incrementTime:1];

  // Send an event to see if that event is accepted.
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);

  // Ensure that the internal event is not dropped even though we have exceeded allowed events
  // count.
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter allows sending network events drops network events when exceeds
 * allowed events count.*/
- (void)testRateLimitingAlgorithmDropsNetworkEventsWhenExceedsAllowedEventsCount {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];

  // Set the rate limit to 60 events per minute.
  [transformer setOverrideNetworkRate:60];
  transformer.networkEventburstSize = 100;
  transformer.allowedNetworkEventsCount = 0;

  // Send an event to see if that event is accepted.
  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomNetworkGDTEvent:@"https://abc.xyz"];

  transformer.lastNetworkEventTime = fakeDate.now;
  [fakeDate incrementTime:1];
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);

  // Ensure that the event is dropped as we have reached the rate limit and the burst size.
  XCTAssertNil([transformer transformGDTEvent:gdtEvent]);

  // Events should be accepted after few seconds.
  transformer.lastTraceEventTime = fakeDate.now;
  [fakeDate incrementTime:1];
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter allows sending events and adjusts the rate dynamically. */
- (void)testRateLimitingAlgorithmWithChangingLimits {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];

  // Set the rate limit to 60 events per minute.
  [transformer setOverrideRate:60];
  transformer.traceEventBurstSize = 100;
  transformer.allowedTraceEventsCount = 0;

  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomTraceGDTEvent:@"trace"];

  transformer.lastTraceEventTime = fakeDate.now;
  [fakeDate incrementTime:1];

  // Send an event to see if that event is accepted.
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);

  // Set the rate limit to 15 events per minute.
  [transformer setOverrideRate:15];

  // Since the rate limit is set to 15 events a minute, incrementing the time by a second would not
  // allow a new event to flow through.
  transformer.lastTraceEventTime = fakeDate.now;
  [fakeDate incrementTime:1];
  XCTAssertNil([transformer transformGDTEvent:gdtEvent]);

  // Incrementing the time with another 4 seconds would allow an event to flow through.
  [fakeDate incrementTime:4];
  XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter drops events when exceeds burst size. */
- (void)testRateLimitingAlgorithmDropsEventsWhenExceedsBurstSize {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];

  transformer.traceEventBurstSize = 60;
  transformer.allowedTraceEventsCount = 60;

  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomTraceGDTEvent:@"trace"];

  // Send an event to see if that event is accepted.
  transformer.lastTraceEventTime = fakeDate.now;

  for (int i = 0; i < 60; i++) {
    XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
  }

  // After 60 events, no more events should be allowed.
  XCTAssertNil([transformer transformGDTEvent:gdtEvent]);
}

/** Validates the rate limiter drops network events when exceeds burst size. */
- (void)testRateLimitingAlgorithmDropsNetworkEventsWhenExceedsBurstSize {
  FPRFakeDate *fakeDate = [[FPRFakeDate alloc] init];
  FPRGDTRateLimiter *transformer = [[FPRGDTRateLimiter alloc] initWithDate:fakeDate];

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];

  transformer.networkEventburstSize = 60;
  transformer.allowedNetworkEventsCount = 60;

  // Send an event to see if that event is accepted.
  GDTCOREvent *gdtEvent = [FPRTestUtils createRandomNetworkGDTEvent:@"https://abc.xyz"];

  transformer.lastNetworkEventTime = fakeDate.now;

  for (int i = 0; i < 60; i++) {
    XCTAssertNotNil([transformer transformGDTEvent:gdtEvent]);
  }

  // After 60 events, no more events should be allowed.
  XCTAssertNil([transformer transformGDTEvent:gdtEvent]);
}

@end

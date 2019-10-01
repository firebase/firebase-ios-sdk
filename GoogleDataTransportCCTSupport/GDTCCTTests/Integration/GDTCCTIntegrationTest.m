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
#import <GoogleDataTransport/GDTTransport.h>

#import <SystemConfiguration/SCNetworkReachability.h>

#import "GDTCCTLibrary/Private/GDTCCTPrioritizer.h"
#import "GDTCCTLibrary/Private/GDTCCTUploader.h"

typedef void (^GDTCCTIntegrationTestBlock)(NSURLSessionUploadTask *_Nullable);

@interface GDTCCTTestDataObject : NSObject <GDTEventDataObject>

@end

@implementation GDTCCTTestDataObject

- (NSData *)transportBytes {
  // Return some random event data corresponding to mapping ID 1018.
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSArray *dataFiles = @[
    @"message-32347456.dat", @"message-35458880.dat", @"message-39882816.dat",
    @"message-40043840.dat", @"message-40657984.dat"
  ];
  NSURL *fileURL = [testBundle URLForResource:dataFiles[arc4random_uniform(5)] withExtension:nil];
  return [NSData dataWithContentsOfURL:fileURL];
}

@end

@interface GDTCCTIntegrationTest : XCTestCase

/** If YES, the network conditions were good enough to allow running integration tests. */
@property(nonatomic) BOOL okToRunTest;

/** If YES, allow the recursive generating of events. */
@property(nonatomic) BOOL generateEvents;

/** The transporter used by the test. */
@property(nonatomic) GDTTransport *transport;

@end

@implementation GDTCCTIntegrationTest

- (void)setUp {
  self.generateEvents = YES;
  SCNetworkReachabilityRef reachabilityRef =
      SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), "https://google.com");
  SCNetworkReachabilityFlags flags;
  Boolean success = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
  if (success) {
    self.okToRunTest =
        (flags & kSCNetworkReachabilityFlagsReachable) == kSCNetworkReachabilityFlagsReachable;
    self.transport = [[GDTTransport alloc] initWithMappingID:@"1018"
                                                transformers:nil
                                                      target:kGDTTargetCCT];
  }
}

/** Generates an event and sends it through the transport infrastructure. */
- (void)generateEvent {
  GDTEvent *event = [self.transport eventForTransport];
  event.dataObject = [[GDTCCTTestDataObject alloc] init];
  [self.transport sendDataEvent:event];
}

/** Generates events recursively at random intervals between 0 and 5 seconds. */
- (void)recursivelyGenerateEvent {
  if (self.generateEvents) {
    GDTEvent *event = [self.transport eventForTransport];
    event.dataObject = [[GDTCCTTestDataObject alloc] init];
    [self.transport sendDataEvent:event];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(arc4random_uniform(6) * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          [self recursivelyGenerateEvent];
        });
  }
}

/** Tests sending data to CCT with a high priority event if network conditions are good. */
- (void)testSendingDataToCCT {
  if (!self.okToRunTest) {
    NSLog(@"Skipping the integration test, as the network conditions weren't good enough.");
    return;
  }

  NSUInteger lengthOfTestToRunInSeconds = 10;
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
  dispatch_source_set_event_handler(timer, ^{
    static int numberOfTimesCalled = 0;
    numberOfTimesCalled++;
    if (numberOfTimesCalled < lengthOfTestToRunInSeconds) {
      [self generateEvent];
    } else {
      dispatch_source_cancel(timer);
    }
  });
  dispatch_resume(timer);

  // Run for a bit, several seconds longer than the previous bit.
  [[NSRunLoop currentRunLoop]
      runUntilDate:[NSDate dateWithTimeIntervalSinceNow:lengthOfTestToRunInSeconds + 5]];

  XCTestExpectation *taskCreatedExpectation = [self expectationWithDescription:@"task created"];
  XCTestExpectation *taskDoneExpectation = [self expectationWithDescription:@"task done"];

  taskCreatedExpectation.assertForOverFulfill = NO;
  taskDoneExpectation.assertForOverFulfill = NO;

  [[GDTCCTUploader sharedInstance]
      addObserver:self
       forKeyPath:@"currentTask"
          options:NSKeyValueObservingOptionNew
          context:(__bridge void *_Nullable)(^(NSURLSessionUploadTask *_Nullable task) {
            if (task) {
              [taskCreatedExpectation fulfill];
            } else {
              [taskDoneExpectation fulfill];
            }
          })];

  // Send a high priority event to flush events.
  GDTEvent *event = [self.transport eventForTransport];
  event.dataObject = [[GDTCCTTestDataObject alloc] init];
  event.qosTier = GDTEventQoSFast;
  [self.transport sendDataEvent:event];

  [self waitForExpectations:@[ taskCreatedExpectation, taskDoneExpectation ] timeout:25.0];

  // Just run for a minute whilst generating events.
  NSInteger secondsToRun = 65;
  [self generateEvents];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(secondsToRun * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   self.generateEvents = NO;
                 });
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:secondsToRun]];
}

// KVO is utilized here to know whether or not the task has completed.
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"currentTask"]) {
    NSURLSessionUploadTask *task = change[NSKeyValueChangeNewKey];
    typedef void (^GDTCCTIntegrationTestBlock)(NSURLSessionUploadTask *_Nullable);
    if (context) {
      GDTCCTIntegrationTestBlock block = (__bridge GDTCCTIntegrationTestBlock)context;
      block([task isKindOfClass:[NSNull class]] ? nil : task);
    }
  }
}

@end

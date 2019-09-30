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

#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCOREventDataObject.h>
#import <GoogleDataTransport/GDTCORTransport.h>

#import <SystemConfiguration/SCNetworkReachability.h>

#import "GDTCCTLibrary/Private/GDTFLLPrioritizer.h"
#import "GDTCCTLibrary/Private/GDTFLLUploader.h"

typedef void (^GDTFLLIntegrationTestBlock)(NSURLSessionUploadTask *_Nullable);

@interface GDTFLLTestDataObject : NSObject <GDTCOREventDataObject>

@end

@implementation GDTFLLTestDataObject

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

@interface GDTFLLIntegrationTest : XCTestCase

/** If YES, the network conditions were good enough to allow running integration tests. */
@property(nonatomic) BOOL okToRunTest;

/** If YES, allow the recursive generating of events. */
@property(nonatomic) BOOL generateEvents;

/** The transporter used by the test. */
@property(nonatomic) GDTCORTransport *transport;

@end

@implementation GDTFLLIntegrationTest

- (void)setUp {
  self.generateEvents = YES;
  SCNetworkReachabilityRef reachabilityRef =
      SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), "https://google.com");
  SCNetworkReachabilityFlags flags;
  Boolean success = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
  if (success) {
    self.okToRunTest =
        (flags & kSCNetworkReachabilityFlagsReachable) == kSCNetworkReachabilityFlagsReachable;
    self.transport = [[GDTCORTransport alloc] initWithMappingID:@"1018"
                                                   transformers:nil
                                                         target:kGDTCORTargetFLL];
  }
}

/** Generates an event and sends it through the transport infrastructure. */
- (void)generateEvent {
  GDTCOREvent *event = [self.transport eventForTransport];
  event.dataObject = [[GDTFLLTestDataObject alloc] init];
  [self.transport sendDataEvent:event];
}

/** Generates events recursively at random intervals between 0 and 5 seconds. */
- (void)recursivelyGenerateEvent {
  if (self.generateEvents) {
    GDTCOREvent *event = [self.transport eventForTransport];
    event.dataObject = [[GDTFLLTestDataObject alloc] init];
    [self.transport sendDataEvent:event];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(arc4random_uniform(6) * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          [self recursivelyGenerateEvent];
        });
  }
}

/** Tests sending data to FLL with a high priority event if network conditions are good. */
- (void)testSendingDataToFLL {
  if (!self.okToRunTest) {
    NSLog(@"Skipping the integration test, as the network conditions weren't good enough.");
    return;
  }

  dispatch_queue_t queue1 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_queue_t queue2 = dispatch_queue_create("com.gdtffl.test", DISPATCH_QUEUE_SERIAL);

  for (int i = 0; i < 12; i++) {
    int result = i % 3;
    if (result == 0) {
      [self generateEvent];
    } else if (result == 1) {
      dispatch_async(queue1, ^{
        [self generateEvent];
      });
    } else if (result == 2) {
      dispatch_async(queue2, ^{
        [self generateEvent];
      });
    }
  }

  XCTestExpectation *taskCreatedExpectation = [self expectationWithDescription:@"task created"];
  XCTestExpectation *taskDoneExpectation = [self expectationWithDescription:@"task done"];
  XCTestExpectation *eventsSent = [self expectationForNotification:<#(nonnull NSNotificationName)#> object:<#(nullable id)#> handler:<#^BOOL(NSNotification * _Nonnull notification)handler#>]

  taskCreatedExpectation.assertForOverFulfill = NO;
  taskDoneExpectation.assertForOverFulfill = NO;

  [[GDTFLLUploader sharedInstance]
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
  GDTCOREvent *event = [self.transport eventForTransport];
  event.dataObject = [[GDTFLLTestDataObject alloc] init];
  event.qosTier = GDTCOREventQoSFast;
  [self.transport sendDataEvent:event];


  // TODO: Validate that all 11 events were sent?
  [self waitForExpectations:@[ taskCreatedExpectation, taskDoneExpectation ] timeout:60.0];
}

- (void)testRunsWithoutCrashing {
//   Just run for a minute whilst generating events.
  NSInteger secondsToRun = 65;
  [self recursivelyGenerateEvent];
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
    typedef void (^GDTFLLIntegrationTestBlock)(NSURLSessionUploadTask *_Nullable);
    if (context) {
      GDTFLLIntegrationTestBlock block = (__bridge GDTFLLIntegrationTestBlock)context;
      block([task isKindOfClass:[NSNull class]] ? nil : task);
    }
  }
}

@end

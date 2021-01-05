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

#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREventDataObject.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORTransport.h"

#import <SystemConfiguration/SCNetworkReachability.h>

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploader.h"

typedef void (^GDTCCTIntegrationTestBlock)(NSURLSessionUploadTask *_Nullable);

@interface GDTCCTTestDataObject : NSObject <GDTCOREventDataObject>

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

/** The total number of events generated for this test. */
@property(nonatomic) NSInteger totalEventsGenerated;

/** The transporter used by the test. */
@property(nonatomic) GDTCORTransport *transport;

/** The local notification listener, to be removed after each test. */
@property(nonatomic, strong) id<NSObject> uploadObserver;

@end

@implementation GDTCCTIntegrationTest

- (void)setUp {
  // Don't recursively generate events by default.
  self.generateEvents = NO;
  self.totalEventsGenerated = 0;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task =
      [session dataTaskWithURL:[NSURL URLWithString:@"https://google.com"]
             completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                 NSError *_Nullable error) {
               if (error) {
                 self.okToRunTest = NO;
               } else {
                 self.okToRunTest = YES;
               }
               self.transport = [[GDTCORTransport alloc] initWithMappingID:@"1018"
                                                              transformers:nil
                                                                    target:kGDTCORTargetCSH];
               dispatch_semaphore_signal(sema);
             }];
  [task resume];
  dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10.0 * NSEC_PER_SEC));
}

- (void)tearDown {
  if (self.uploadObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:self.uploadObserver];
    self.uploadObserver = nil;
  }

  [super tearDown];
}

/** Generates an event and sends it through the transport infrastructure. */
- (void)generateEventWithQoSTier:(GDTCOREventQoS)qosTier {
  GDTCOREvent *event = [self.transport eventForTransport];
  event.dataObject = [[GDTCCTTestDataObject alloc] init];
  event.qosTier = qosTier;
  [self.transport sendDataEvent:event
                     onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                       NSLog(@"Storing a data event completed.");
                     }];
  dispatch_async(dispatch_get_main_queue(), ^{
    self.totalEventsGenerated += 1;
  });
}

/** Generates events recursively at random intervals between 0 and 5 seconds. */
- (void)recursivelyGenerateEvent {
  if (self.generateEvents) {
    [self generateEventWithQoSTier:GDTCOREventQosDefault];
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

  // Send a number of events across multiple queues in order to ensure the threading is working as
  // expected.
  dispatch_queue_t queue1 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_queue_t queue2 = dispatch_queue_create("com.gdtcct.test", DISPATCH_QUEUE_SERIAL);
  for (int i = 0; i < 12; i++) {
    int result = i % 3;
    if (result == 0) {
      [self generateEventWithQoSTier:GDTCOREventQosDefault];
    } else if (result == 1) {
      dispatch_async(queue1, ^{
        [self generateEventWithQoSTier:GDTCOREventQosDefault];
      });
    } else if (result == 2) {
      dispatch_async(queue2, ^{
        [self generateEventWithQoSTier:GDTCOREventQosDefault];
      });
    }
  }

  XCTestExpectation *eventsUploaded =
      [self expectationWithDescription:@"Events were successfully uploaded to CCT."];
  [eventsUploaded setAssertForOverFulfill:NO];
  self.uploadObserver = [self uploadNotificationObserverWithExpectation:eventsUploaded];

  // Send a high priority event to flush events.
  [self generateEventWithQoSTier:GDTCOREventQoSFast];

  // Validate that at least one event was uploaded.
  [self waitForExpectations:@[ eventsUploaded ] timeout:60.0];
}

- (void)testRunsWithoutCrashing {
  if (!self.okToRunTest) {
    NSLog(@"Skipping the integration test, as the network conditions weren't good enough.");
    return;
  }
  // Just run for a minute whilst generating events.
  NSInteger secondsToRun = 65;
  self.generateEvents = YES;

  XCTestExpectation *eventsUploaded =
      [self expectationWithDescription:@"Events were successfully uploaded to CCT."];
  [eventsUploaded setAssertForOverFulfill:NO];

  self.uploadObserver = [self uploadNotificationObserverWithExpectation:eventsUploaded];

  [self recursivelyGenerateEvent];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(secondsToRun * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   self.generateEvents = NO;

                   // Send a high priority event to flush other events.
                   [self generateEventWithQoSTier:GDTCOREventQoSFast];

                   [self waitForExpectations:@[ eventsUploaded ] timeout:60.0];
                 });
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:secondsToRun + 5]];
}

/** Registers a notification observer for when an upload occurs and returns the observer. */
- (id<NSObject>)uploadNotificationObserverWithExpectation:(XCTestExpectation *)expectation {
  return [[NSNotificationCenter defaultCenter]
      addObserverForName:GDTCCTUploadCompleteNotification
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification *_Nonnull note) {
                NSNumber *eventsUploadedNumber = note.object;
                if (![eventsUploadedNumber isKindOfClass:[NSNumber class]]) {
                  XCTFail(@"Expected notification object of events uploaded, "
                          @"instead got a %@.",
                          [eventsUploadedNumber class]);
                }
                // We don't necessarily need *all* uploads to have happened, just some (due to
                // timing). As long as there are some events uploaded, call it a success.
                NSInteger eventsUploaded = eventsUploadedNumber.integerValue;
                if (eventsUploaded > 0 && eventsUploaded <= self.totalEventsGenerated) {
                  [expectation fulfill];
                }
              }];
}

@end

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

#import <XCTest/XCTest.h>

#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREventDataObject.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORTransport.h"

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORTransformer_Private.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

#import "GoogleDataTransport/GDTCORTests/Lifecycle/Helpers/GDTCORLifecycleTestUploader.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORUploadCoordinator+Testing.h"

/** Waits for the result of waitBlock to be YES, or times out and fails.
 *
 * @param waitBlock The block to periodically execute.
 * @param timeInterval The timeout.
 */
#define GDTCORWaitForBlock(waitBlock, timeInterval)                                               \
  {                                                                                               \
    NSPredicate *pred =                                                                           \
        [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject,                       \
                                              NSDictionary<NSString *, id> *_Nullable bindings) { \
          return waitBlock();                                                                     \
        }];                                                                                       \
    XCTestExpectation *expectation = [self expectationForPredicate:pred                           \
                                               evaluatedWithObject:nil                            \
                                                           handler:nil];                          \
    [self waitForExpectations:@[ expectation ] timeout:timeInterval];                             \
  }

/** A test-only event data object used in this integration test. */
@interface GDTCORLifecycleTestEvent : NSObject <GDTCOREventDataObject>

@end

@implementation GDTCORLifecycleTestEvent

- (NSData *)transportBytes {
  // In real usage, protobuf's -data method or a custom implementation using nanopb are used.
  return [[NSString stringWithFormat:@"%@", [NSDate date]] dataUsingEncoding:NSUTF8StringEncoding];
}

@end

@interface GDTCORLifecycleTest : XCTestCase

/** The test uploader. */
@property(nonatomic) GDTCORLifecycleTestUploader *uploader;

@end

@implementation GDTCORLifecycleTest

- (void)setUp {
  [super setUp];
  [[GDTCORFlatFileStorage sharedInstance] reset];
  self.uploader = [[GDTCORLifecycleTestUploader alloc] init];
  [[GDTCORRegistrar sharedInstance] registerUploader:self.uploader target:kGDTCORTargetTest];
}

- (void)tearDown {
  [super tearDown];
  self.uploader = nil;

  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORFlatFileStorage sharedInstance] reset];
  [[GDTCORUploadCoordinator sharedInstance] reset];
}

// Backgrounding and foregrounding are only applicable for iOS and tvOS.
#if TARGET_OS_IOS || TARGET_OS_TV

/** Tests that the library serializes itself to disk when the app backgrounds. */
- (void)testBackgrounding {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"test"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
  XCTAssertTrue([GDTCORApplication sharedApplication].isRunningInBackground);

  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORLifecycleTestEvent alloc] init];
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertFalse(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  [transport sendDataEvent:event];
  dispatch_sync([GDTCORTransformer sharedInstance].eventWritingQueue, ^{
                });
  expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertTrue(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

#endif  // #if TARGET_OS_IOS || TARGET_OS_TV

/** Tests that the library gracefully stops doing stuff when terminating. */
- (void)testTermination {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"test"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTCORApplicationWillTerminateNotification object:nil];

  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORLifecycleTestEvent alloc] init];
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertFalse(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  [transport sendDataEvent:event];
  dispatch_sync([GDTCORTransformer sharedInstance].eventWritingQueue, ^{
                });
  expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertTrue(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

@end

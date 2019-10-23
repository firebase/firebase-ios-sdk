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

#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCOREventDataObject.h>
#import <GoogleDataTransport/GDTCORTransport.h>

#import "GDTCORLibrary/Private/GDTCORStorage_Private.h"
#import "GDTCORLibrary/Private/GDTCORTransformer_Private.h"
#import "GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

#import "GDTCORTests/Lifecycle/Helpers/GDTCORLifecycleTestPrioritizer.h"
#import "GDTCORTests/Lifecycle/Helpers/GDTCORLifecycleTestUploader.h"

#import "GDTCORTests/Common/Categories/GDTCORStorage+Testing.h"
#import "GDTCORTests/Common/Categories/GDTCORUploadCoordinator+Testing.h"

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
                                               evaluatedWithObject:[[NSObject alloc] init]        \
                                                           handler:^BOOL {                        \
                                                             return YES;                          \
                                                           }];                                    \
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

/** The test prioritizer. */
@property(nonatomic) GDTCORLifecycleTestPrioritizer *prioritizer;

/** The test uploader. */
@property(nonatomic) GDTCORLifecycleTestUploader *uploader;

@end

@implementation GDTCORLifecycleTest

- (void)setUp {
  [super setUp];
  // Don't check the error, because it'll be populated in cases where the file doesn't exist.
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtPath:[GDTCORStorage archivePath] error:&error];
  self.uploader = [[GDTCORLifecycleTestUploader alloc] init];
  [[GDTCORRegistrar sharedInstance] registerUploader:self.uploader target:kGDTCORTargetTest];

  self.prioritizer = [[GDTCORLifecycleTestPrioritizer alloc] init];
  [[GDTCORRegistrar sharedInstance] registerPrioritizer:self.prioritizer target:kGDTCORTargetTest];
  [[GDTCORStorage sharedInstance] reset];
  [[GDTCORUploadCoordinator sharedInstance] reset];
}

// Backgrounding and foregrounding are only applicable for iOS and tvOS.
#if TARGET_OS_IOS || TARGET_OS_TV

/** Tests that the library serializes itself to disk when the app backgrounds. */
- (void)testBackgrounding {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"test"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORLifecycleTestEvent alloc] init];
  XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 0);
  [transport sendDataEvent:event];
  GDTCORWaitForBlock(
      ^BOOL {
        return [GDTCORStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
  XCTAssertTrue([GDTCORApplication sharedApplication].isRunningInBackground);

  GDTCORWaitForBlock(
      ^BOOL {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm fileExistsAtPath:[GDTCORStorage archivePath] isDirectory:NULL];
      },
      5.0);
}

/** Tests that the library deserializes itself from disk when the app foregrounds. */
- (void)testForegrounding {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"test"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORLifecycleTestEvent alloc] init];
  XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 0);
  [transport sendDataEvent:event];
  GDTCORWaitForBlock(
      ^BOOL {
        return [GDTCORStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];

  GDTCORWaitForBlock(
      ^BOOL {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm fileExistsAtPath:[GDTCORStorage archivePath] isDirectory:NULL];
      },
      5.0);

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  [notifCenter postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
  XCTAssertFalse([GDTCORApplication sharedApplication].isRunningInBackground);
  GDTCORWaitForBlock(
      ^BOOL {
        return [GDTCORStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);
}
#endif  // #if TARGET_OS_IOS || TARGET_OS_TV

/** Tests that the library gracefully stops doing stuff when terminating. */
- (void)testTermination {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"test"
                                                             transformers:nil
                                                                   target:kGDTCORTargetTest];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = [[GDTCORLifecycleTestEvent alloc] init];
  XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 0);
  [transport sendDataEvent:event];
  GDTCORWaitForBlock(
      ^BOOL {
        return [GDTCORStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTCORApplicationWillTerminateNotification object:nil];
  GDTCORWaitForBlock(
      ^BOOL {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm fileExistsAtPath:[GDTCORStorage archivePath] isDirectory:NULL];
      },
      5.0);
}

@end

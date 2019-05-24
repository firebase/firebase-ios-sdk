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

#import <GoogleDataTransport/GDTEvent.h>
#import <GoogleDataTransport/GDTEventDataObject.h>
#import <GoogleDataTransport/GDTTransport.h>

#import "GDTLibrary/Private/GDTStorage_Private.h"
#import "GDTLibrary/Private/GDTTransformer_Private.h"
#import "GDTLibrary/Private/GDTUploadCoordinator.h"

#import "GDTTests/Lifecycle/Helpers/GDTLifecycleTestPrioritizer.h"
#import "GDTTests/Lifecycle/Helpers/GDTLifecycleTestUploader.h"

#import "GDTTests/Common/Categories/GDTStorage+Testing.h"
#import "GDTTests/Common/Categories/GDTUploadCoordinator+Testing.h"

/** Waits for the result of waitBlock to be YES, or times out and fails.
 *
 * @param waitBlock The block to periodically execute.
 * @param timeInterval The timeout.
 */
#define GDTWaitForBlock(waitBlock, timeInterval)                                                  \
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
@interface GDTLifecycleTestEvent : NSObject <GDTEventDataObject>

@end

@implementation GDTLifecycleTestEvent

- (NSData *)transportBytes {
  // In real usage, protobuf's -data method or a custom implementation using nanopb are used.
  return [[NSString stringWithFormat:@"%@", [NSDate date]] dataUsingEncoding:NSUTF8StringEncoding];
}

@end

@interface GDTLifecycleTest : XCTestCase

/** The test prioritizer. */
@property(nonatomic) GDTLifecycleTestPrioritizer *prioritizer;

/** The test uploader. */
@property(nonatomic) GDTLifecycleTestUploader *uploader;

@end

@implementation GDTLifecycleTest

- (void)setUp {
  [super setUp];
  // Don't check the error, because it'll be populated in cases where the file doesn't exist.
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtPath:[GDTStorage archivePath] error:&error];
  self.uploader = [[GDTLifecycleTestUploader alloc] init];
  [[GDTRegistrar sharedInstance] registerUploader:self.uploader target:kGDTTargetTest];

  self.prioritizer = [[GDTLifecycleTestPrioritizer alloc] init];
  [[GDTRegistrar sharedInstance] registerPrioritizer:self.prioritizer target:kGDTTargetTest];
  [[GDTStorage sharedInstance] reset];
  [[GDTUploadCoordinator sharedInstance] reset];
}

/** Tests that the library serializes itself to disk when the app backgrounds. */
- (void)testBackgrounding {
  GDTTransport *transport = [[GDTTransport alloc] initWithMappingID:@"test"
                                                       transformers:nil
                                                             target:kGDTTargetTest];
  GDTEvent *event = [transport eventForTransport];
  event.dataObject = [[GDTLifecycleTestEvent alloc] init];
  XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
  [transport sendDataEvent:event];
  GDTWaitForBlock(
      ^BOOL {
        return [GDTStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationDidEnterBackgroundNotification object:nil];
  XCTAssertTrue([GDTStorage sharedInstance].runningInBackground);
  XCTAssertTrue([GDTUploadCoordinator sharedInstance].runningInBackground);
  GDTWaitForBlock(
      ^BOOL {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm fileExistsAtPath:[GDTStorage archivePath] isDirectory:NULL];
      },
      5.0);
}

/** Tests that the library deserializes itself from disk when the app foregrounds. */
- (void)testForegrounding {
  GDTTransport *transport = [[GDTTransport alloc] initWithMappingID:@"test"
                                                       transformers:nil
                                                             target:kGDTTargetTest];
  GDTEvent *event = [transport eventForTransport];
  event.dataObject = [[GDTLifecycleTestEvent alloc] init];
  XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
  [transport sendDataEvent:event];
  GDTWaitForBlock(
      ^BOOL {
        return [GDTStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationDidEnterBackgroundNotification object:nil];

  GDTWaitForBlock(
      ^BOOL {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm fileExistsAtPath:[GDTStorage archivePath] isDirectory:NULL];
      },
      5.0);

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  [notifCenter postNotificationName:kGDTApplicationWillEnterForegroundNotification object:nil];
  XCTAssertFalse([GDTStorage sharedInstance].runningInBackground);
  XCTAssertFalse([GDTUploadCoordinator sharedInstance].runningInBackground);
  GDTWaitForBlock(
      ^BOOL {
        return [GDTStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);
}

/** Tests that the library gracefully stops doing stuff when terminating. */
- (void)testTermination {
  GDTTransport *transport = [[GDTTransport alloc] initWithMappingID:@"test"
                                                       transformers:nil
                                                             target:kGDTTargetTest];
  GDTEvent *event = [transport eventForTransport];
  event.dataObject = [[GDTLifecycleTestEvent alloc] init];
  XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
  [transport sendDataEvent:event];
  GDTWaitForBlock(
      ^BOOL {
        return [GDTStorage sharedInstance].storedEvents.count > 0;
      },
      5.0);

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationWillTerminateNotification object:nil];
  GDTWaitForBlock(
      ^BOOL {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm fileExistsAtPath:[GDTStorage archivePath] isDirectory:NULL];
      },
      5.0);
}

@end

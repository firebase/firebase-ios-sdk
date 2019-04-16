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

#import "Tests/Unit/GDTTestCase.h"

#import "Library/Private/GDTUploadCoordinator.h"
#import "Library/Private/GDTUploadCoordinator_Private.h"

#import "Tests/Common/Categories/GDTRegistrar+Testing.h"
#import "Tests/Common/Categories/GDTUploadCoordinator+Testing.h"

#import "Tests/Common/Fakes/GDTStorageFake.h"

#import "Tests/Unit/Helpers/GDTEventGenerator.h"
#import "Tests/Unit/Helpers/GDTTestPrioritizer.h"
#import "Tests/Unit/Helpers/GDTTestUploadPackage.h"
#import "Tests/Unit/Helpers/GDTTestUploader.h"

@interface GDTUploadCoordinatorTest : GDTTestCase

/** A storage fake to inject into GDTUploadCoordinator. */
@property(nonatomic) GDTStorageFake *storageFake;

/** A test prioritizer. */
@property(nonatomic) GDTTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDTTestUploader *uploader;

/** A target for the prioritizer and uploader to use. */
@property(nonatomic) GDTTarget target;

@end

@implementation GDTUploadCoordinatorTest

- (void)setUp {
  [super setUp];
  self.storageFake = [[GDTStorageFake alloc] init];
  self.target = 42;
  self.prioritizer = [[GDTTestPrioritizer alloc] init];
  self.uploader = [[GDTTestUploader alloc] init];

  [[GDTRegistrar sharedInstance] registerPrioritizer:_prioritizer target:_target];
  [[GDTRegistrar sharedInstance] registerUploader:_uploader target:_target];

  GDTUploadCoordinator *uploadCoordinator = [GDTUploadCoordinator sharedInstance];
  uploadCoordinator.storage = self.storageFake;
  uploadCoordinator.timerInterval = NSEC_PER_SEC;
  uploadCoordinator.timerLeeway = 0;
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    [[GDTUploadCoordinator sharedInstance] reset];
  });
  [[GDTRegistrar sharedInstance] reset];
  self.storageFake = nil;
  self.prioritizer = nil;
  self.uploader = nil;
}

/** Tests the default initializer. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTUploadCoordinator sharedInstance], [GDTUploadCoordinator sharedInstance]);
}

/** Tests that forcing a event upload works. */
- (void)testForceUploadEvents {
  GDTTestUploadPackage *uploadPackage = [[GDTTestUploadPackage alloc] init];
  uploadPackage.events = [GDTEventGenerator generate3StoredEvents];
  self.prioritizer.uploadPackage = uploadPackage;
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadEventsBlock =
      ^(GDTUploadPackage *_Nonnull package, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        [expectation fulfill];
      };
  XCTAssertNoThrow([[GDTUploadCoordinator sharedInstance] forceUploadForTarget:_target]);
  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

/** Tests forcing an upload while that target currently has a request in flight queues. */
- (void)testForceUploadEventsEnqueuesIftargetAlreadyHasEventsInFlight {
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 100;
  [GDTUploadCoordinator sharedInstance].timerLeeway = NSEC_PER_SEC / 1000;
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadEventsBlock =
      ^(GDTUploadPackage *_Nonnull package, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        [expectation fulfill];
      };
  GDTTestUploadPackage *uploadPackage = [[GDTTestUploadPackage alloc] init];
  uploadPackage.events = [GDTEventGenerator generate3StoredEvents];
  self.prioritizer.uploadPackage = uploadPackage;
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    [GDTUploadCoordinator sharedInstance].targetToInFlightEventSet[@(self->_target)] =
        [[NSSet alloc] init];
  });
  XCTAssertNoThrow([[GDTUploadCoordinator sharedInstance] forceUploadForTarget:_target]);
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertEqual([GDTUploadCoordinator sharedInstance].forcedUploadQueue.count, 1);
    [GDTUploadCoordinator sharedInstance].onCompleteBlock(
        self.target, [GDTClock clockSnapshotInTheFuture:1000], nil);
  });
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests the timer is running at the desired frequency. */
- (void)testTimerIsRunningAtDesiredFrequency {
  __block int numberOfTimesCalled = 0;
  self.prioritizer.uploadPackageWithConditionsBlock = ^{
    numberOfTimesCalled++;
  };
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    // Timer should fire 10 times a second.
    [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
    [GDTUploadCoordinator sharedInstance].timerLeeway = 0;
  });
  [[GDTUploadCoordinator sharedInstance] startTimer];

  // Run for 1 second.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];

  // It's expected that the timer called the prioritizer 10 times +/- 3 during that 1 second + the
  // coordinator running before that.
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertGreaterThan(numberOfTimesCalled, 4);  // Some latency is expected on a busy system.
  });
}

/** Tests uploading events via the coordinator timer. */
- (void)testUploadingEventsViaTimer {
  __block int uploadAttempts = 0;
  __weak GDTUploadCoordinatorTest *weakSelf = self;
  GDTTestUploadPackage *uploadPackage = [[GDTTestUploadPackage alloc] init];
  uploadPackage.events = [GDTEventGenerator generate3StoredEvents];
  self.prioritizer.uploadPackage = uploadPackage;
  self.uploader.uploadEventsBlock =
      ^(GDTUploadPackage *_Nonnull package, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        GDTUploadCoordinatorTest *strongSelf = weakSelf;
        completionBlock(strongSelf->_target, [GDTClock clockSnapshotInTheFuture:100], nil);
        uploadAttempts++;
      };
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
  [GDTUploadCoordinator sharedInstance].timerLeeway = 0;

  [[GDTUploadCoordinator sharedInstance] startTimer];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    // More than two attempts should have been made.
    XCTAssertGreaterThan(uploadAttempts, 2);
  });
}

/** Tests the situation in which the uploader failed to upload the events for some reason. */
- (void)testThatAFailedUploadResultsInAnEventualRetry {
  __block int uploadAttempts = 0;
  __weak GDTUploadCoordinatorTest *weakSelf = self;
  GDTTestUploadPackage *uploadPackage = [[GDTTestUploadPackage alloc] init];
  uploadPackage.events = [GDTEventGenerator generate3StoredEvents];
  self.prioritizer.uploadPackage = uploadPackage;
  self.uploader.uploadEventsBlock =
      ^(GDTUploadPackage *_Nonnull package, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        GDTUploadCoordinatorTest *strongSelf = weakSelf;
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:1337 userInfo:nil];
        completionBlock(strongSelf->_target, [GDTClock clockSnapshotInTheFuture:100], error);
        uploadAttempts++;
      };
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
  [GDTUploadCoordinator sharedInstance].timerLeeway = 0;

  [[GDTUploadCoordinator sharedInstance] startTimer];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    // More than two attempts should have been made.
    XCTAssertGreaterThan(uploadAttempts, 2);
  });
}

@end

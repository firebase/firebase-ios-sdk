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

#import "GDTTestCase.h"

#import "GDTUploadCoordinator.h"
#import "GDTUploadCoordinator_Private.h"

#import "GDTLogStorageFake.h"
#import "GDTRegistrar+Testing.h"
#import "GDTTestPrioritizer.h"
#import "GDTTestUploader.h"
#import "GDTUploadCoordinator+Testing.h"

@interface GDTUploadCoordinatorTest : GDTTestCase

/** A log storage fake to inject into GDTUploadCoordinator. */
@property(nonatomic) GDTLogStorageFake *storageFake;

/** A test prioritizer. */
@property(nonatomic) GDTTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDTTestUploader *uploader;

/** A log target for the prioritizer and uploader to use. */
@property(nonatomic) GDTLogTarget logTarget;

@end

@implementation GDTUploadCoordinatorTest

- (void)setUp {
  [super setUp];
  self.storageFake = [[GDTLogStorageFake alloc] init];
  self.logTarget = 42;
  self.prioritizer = [[GDTTestPrioritizer alloc] init];
  self.uploader = [[GDTTestUploader alloc] init];

  [[GDTRegistrar sharedInstance] registerPrioritizer:_prioritizer logTarget:_logTarget];
  [[GDTRegistrar sharedInstance] registerUploader:_uploader logTarget:_logTarget];

  GDTUploadCoordinator *uploadCoordinator = [GDTUploadCoordinator sharedInstance];
  uploadCoordinator.logStorage = self.storageFake;
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

/** Tests that forcing a log upload works. */
- (void)testForceUploadLogs {
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        [expectation fulfill];
      };
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  NSSet<NSNumber *> *logSet = [NSSet setWithObjects:@(1234), nil];
  XCTAssertNoThrow([[GDTUploadCoordinator sharedInstance] forceUploadLogs:logSet
                                                                   target:_logTarget]);
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    [self waitForExpectations:@[ expectation ] timeout:0.1];
  });
}

/** Tests forcing an upload while that log target currently has a request in flight queues. */
- (void)testForceUploadLogsEnqueuesIfLogTargetAlreadyHasLogsInFlight {
  [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 100;
  [GDTUploadCoordinator sharedInstance].timerLeeway = NSEC_PER_SEC / 1000;
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        [expectation fulfill];
      };
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  NSSet<NSNumber *> *logSet = [NSSet setWithObjects:@(1234), nil];
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    [GDTUploadCoordinator sharedInstance].logTargetToInFlightLogSet[@(self->_logTarget)] =
        [[NSSet alloc] init];
  });
  XCTAssertNoThrow([[GDTUploadCoordinator sharedInstance] forceUploadLogs:logSet
                                                                   target:_logTarget]);
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertEqual([GDTUploadCoordinator sharedInstance].forcedUploadQueue.count, 1);
    [GDTUploadCoordinator sharedInstance].onCompleteBlock(
        self.logTarget, [GDTClock clockSnapshotInTheFuture:1000], nil);
  });
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    [self waitForExpectations:@[ expectation ] timeout:0.1];
  });
}

/** Tests the timer is running at the desired frequency. */
- (void)testTimerIsRunningAtDesiredFrequency {
  __block int numberOfTimesCalled = 0;
  self.prioritizer.logsForNextUploadBlock = ^{
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
    XCTAssertEqualWithAccuracy(numberOfTimesCalled, 10, 3);
  });
}

/** Tests uploading logs via the coordinator timer. */
- (void)testUploadingLogsViaTimer {
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  __block int uploadAttempts = 0;
  __weak GDTUploadCoordinatorTest *weakSelf = self;
  self.prioritizer.logsForNextUploadFake = [NSSet setWithObjects:@(1234), nil];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        GDTUploadCoordinatorTest *strongSelf = weakSelf;
        completionBlock(strongSelf->_logTarget, [GDTClock clockSnapshotInTheFuture:100], nil);
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

/** Tests the situation in which the uploader failed to upload the logs for some reason. */
- (void)testThatAFailedUploadResultsInAnEventualRetry {
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  __block int uploadAttempts = 0;
  __weak GDTUploadCoordinatorTest *weakSelf = self;
  self.prioritizer.logsForNextUploadFake = [NSSet setWithObjects:@(1234), nil];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDTUploaderCompletionBlock _Nonnull completionBlock) {
        GDTUploadCoordinatorTest *strongSelf = weakSelf;
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:1337 userInfo:nil];
        completionBlock(strongSelf->_logTarget, [GDTClock clockSnapshotInTheFuture:100], error);
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

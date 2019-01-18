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

#import "GDLTestCase.h"

#import "GDLUploadCoordinator.h"
#import "GDLUploadCoordinator_Private.h"

#import "GDLLogStorageFake.h"
#import "GDLRegistrar+Testing.h"
#import "GDLTestPrioritizer.h"
#import "GDLTestUploader.h"
#import "GDLUploadCoordinator+Testing.h"

@interface GDLUploadCoordinatorTest : GDLTestCase

/** A log storage fake to inject into GDLUploadCoordinator. */
@property(nonatomic) GDLLogStorageFake *storageFake;

/** A test prioritizer. */
@property(nonatomic) GDLTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDLTestUploader *uploader;

/** A log target for the prioritizer and uploader to use. */
@property(nonatomic) GDLLogTarget logTarget;

@end

@implementation GDLUploadCoordinatorTest

- (void)setUp {
  [super setUp];
  self.storageFake = [[GDLLogStorageFake alloc] init];
  self.logTarget = 42;
  self.prioritizer = [[GDLTestPrioritizer alloc] init];
  self.uploader = [[GDLTestUploader alloc] init];

  [[GDLRegistrar sharedInstance] registerPrioritizer:_prioritizer logTarget:_logTarget];
  [[GDLRegistrar sharedInstance] registerUploader:_uploader logTarget:_logTarget];

  GDLUploadCoordinator *uploadCoordinator = [GDLUploadCoordinator sharedInstance];
  uploadCoordinator.logStorage = self.storageFake;
  uploadCoordinator.timerInterval = NSEC_PER_SEC;
  uploadCoordinator.timerLeeway = 0;
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    [[GDLUploadCoordinator sharedInstance] reset];
  });
  [[GDLRegistrar sharedInstance] reset];
  self.storageFake = nil;
  self.prioritizer = nil;
  self.uploader = nil;
}

/** Tests the default initializer. */
- (void)testSharedInstance {
  XCTAssertEqual([GDLUploadCoordinator sharedInstance], [GDLUploadCoordinator sharedInstance]);
}

/** Tests that forcing a log upload works. */
- (void)testForceUploadLogs {
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDLUploaderCompletionBlock _Nonnull completionBlock) {
        [expectation fulfill];
      };
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  NSSet<NSNumber *> *logSet = [NSSet setWithObjects:@(1234), nil];
  XCTAssertNoThrow([[GDLUploadCoordinator sharedInstance] forceUploadLogs:logSet
                                                                   target:_logTarget]);
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    [self waitForExpectations:@[ expectation ] timeout:0.1];
  });
}

/** Tests forcing an upload while that log target currently has a request in flight queues. */
- (void)testForceUploadLogsEnqueuesIfLogTargetAlreadyHasLogsInFlight {
  [GDLUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 100;
  [GDLUploadCoordinator sharedInstance].timerLeeway = NSEC_PER_SEC / 1000;
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDLUploaderCompletionBlock _Nonnull completionBlock) {
        [expectation fulfill];
      };
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  NSSet<NSNumber *> *logSet = [NSSet setWithObjects:@(1234), nil];
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    [GDLUploadCoordinator sharedInstance].logTargetToInFlightLogSet[@(self->_logTarget)] =
        [[NSSet alloc] init];
  });
  XCTAssertNoThrow([[GDLUploadCoordinator sharedInstance] forceUploadLogs:logSet
                                                                   target:_logTarget]);
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertEqual([GDLUploadCoordinator sharedInstance].forcedUploadQueue.count, 1);
    [[GDLUploadCoordinator sharedInstance].logTargetToInFlightLogSet removeAllObjects];
    [GDLUploadCoordinator sharedInstance].onCompleteBlock(
        self.logTarget, [GDLClock clockSnapshotInTheFuture:1000], nil);
  });
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    [self waitForExpectations:@[ expectation ] timeout:0.1];
  });
}

/** Tests the timer is running at the desired frequency. */
- (void)testTimerIsRunningAtDesiredFrequency {
  __block int numberOfTimesCalled = 0;
  self.prioritizer.logsForNextUploadBlock = ^{
    numberOfTimesCalled++;
  };
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    // Timer should fire 10 times a second.
    [GDLUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
    [GDLUploadCoordinator sharedInstance].timerLeeway = 0;
  });
  [[GDLUploadCoordinator sharedInstance] startTimer];

  // Run for 1 second.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];

  // It's expected that the timer called the prioritizer 10 times +/- 3 during that 1 second + the
  // coordinator running before that.
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertEqualWithAccuracy(numberOfTimesCalled, 10, 3);
  });
}

/** Tests uploading logs via the coordinator timer. */
- (void)testUploadingLogsViaTimer {
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  __block int uploadAttempts = 0;
  __weak GDLUploadCoordinatorTest *weakSelf = self;
  self.prioritizer.logsForNextUploadFake = [NSSet setWithObjects:@(1234), nil];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDLUploaderCompletionBlock _Nonnull completionBlock) {
        GDLUploadCoordinatorTest *strongSelf = weakSelf;
        completionBlock(strongSelf->_logTarget, [GDLClock clockSnapshotInTheFuture:100], nil);
        uploadAttempts++;
      };
  [GDLUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
  [GDLUploadCoordinator sharedInstance].timerLeeway = 0;

  [[GDLUploadCoordinator sharedInstance] startTimer];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    // More than two attempts should have been made.
    XCTAssertGreaterThan(uploadAttempts, 2);
  });
}

/** Tests the situation in which the uploader failed to upload the logs for some reason. */
- (void)testThatAFailedUploadResultsInAnEventualRetry {
  NSSet<NSURL *> *fakeLogSet = [NSSet setWithObjects:[NSURL URLWithString:@"file:///fake"], nil];
  self.storageFake.logsToReturnFromLogHashesToFiles = fakeLogSet;
  __block int uploadAttempts = 0;
  __weak GDLUploadCoordinatorTest *weakSelf = self;
  self.prioritizer.logsForNextUploadFake = [NSSet setWithObjects:@(1234), nil];
  self.uploader.uploadLogsBlock =
      ^(NSSet<NSURL *> *_Nonnull logFiles, GDLUploaderCompletionBlock _Nonnull completionBlock) {
        GDLUploadCoordinatorTest *strongSelf = weakSelf;
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:1337 userInfo:nil];
        completionBlock(strongSelf->_logTarget, [GDLClock clockSnapshotInTheFuture:100], error);
        uploadAttempts++;
      };
  [GDLUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
  [GDLUploadCoordinator sharedInstance].timerLeeway = 0;

  [[GDLUploadCoordinator sharedInstance] startTimer];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  dispatch_sync([GDLUploadCoordinator sharedInstance].coordinationQueue, ^{
    // More than two attempts should have been made.
    XCTAssertGreaterThan(uploadAttempts, 2);
  });
}

@end

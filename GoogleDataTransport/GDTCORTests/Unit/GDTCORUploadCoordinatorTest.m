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

#import "GDTCORTests/Unit/GDTCORTestCase.h"

#import "GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

#import "GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"
#import "GDTCORTests/Common/Categories/GDTCORUploadCoordinator+Testing.h"

#import "GDTCORTests/Common/Fakes/GDTCORStorageFake.h"

#import "GDTCORTests/Unit/Helpers/GDTCOREventGenerator.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestPrioritizer.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestUploadPackage.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

@interface GDTCORUploadCoordinatorTest : GDTCORTestCase

/** A storage fake to inject into GDTCORUploadCoordinator. */
@property(nonatomic) GDTCORStorageFake *storageFake;

/** A test prioritizer. */
@property(nonatomic) GDTCORTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDTCORTestUploader *uploader;

@end

@implementation GDTCORUploadCoordinatorTest

- (void)setUp {
  [super setUp];
  self.storageFake = [[GDTCORStorageFake alloc] init];
  self.prioritizer = [[GDTCORTestPrioritizer alloc] init];
  self.uploader = [[GDTCORTestUploader alloc] init];

  [[GDTCORRegistrar sharedInstance] registerPrioritizer:_prioritizer target:kGDTCORTargetTest];
  [[GDTCORRegistrar sharedInstance] registerUploader:_uploader target:kGDTCORTargetTest];

  GDTCORUploadCoordinator *uploadCoordinator = [GDTCORUploadCoordinator sharedInstance];
  uploadCoordinator.storage = self.storageFake;
  uploadCoordinator.timerInterval = NSEC_PER_SEC;
  uploadCoordinator.timerLeeway = 0;
}

- (void)tearDown {
  [super tearDown];
  [[GDTCORUploadCoordinator sharedInstance] reset];
  [[GDTCORRegistrar sharedInstance] reset];
  self.storageFake = nil;
  self.prioritizer = nil;
  self.uploader = nil;
}

/** Tests the default initializer. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTCORUploadCoordinator sharedInstance],
                 [GDTCORUploadCoordinator sharedInstance]);
}

/** Tests that forcing a event upload works. */
- (void)testForceUploadEvents {
  self.prioritizer.events = [GDTCOREventGenerator generate3StoredEvents];
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadPackageBlock = ^(GDTCORUploadPackage *_Nonnull package) {
    [expectation fulfill];
  };
  XCTAssertNoThrow(
      [[GDTCORUploadCoordinator sharedInstance] forceUploadForTarget:kGDTCORTargetTest]);
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests the timer is running at the desired frequency. */
- (void)testTimerIsRunningAtDesiredFrequency {
  __block int numberOfTimesCalled = 0;
  self.prioritizer.uploadPackageWithConditionsBlock = ^{
    numberOfTimesCalled++;
  };
  dispatch_sync([GDTCORUploadCoordinator sharedInstance].coordinationQueue, ^{
    // Timer should fire 1 times a second.
    [GDTCORUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC;
    [GDTCORUploadCoordinator sharedInstance].timerLeeway = 0;
  });
  [[GDTCORUploadCoordinator sharedInstance] startTimer];

  // Run for 5 seconds.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];

  // It's expected that the timer called the prioritizer 5 times +/- 1 during that 1 second + the
  // coordinator running before that.
  dispatch_sync([GDTCORUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertGreaterThan(numberOfTimesCalled, 4);  // Some latency is expected on a busy system.
  });
}

/** Tests uploading events via the coordinator timer. */
- (void)testUploadingEventsViaTimer {
  __block int uploadAttempts = 0;
  self.prioritizer.events = [GDTCOREventGenerator generate3StoredEvents];
  self.uploader.uploadPackageBlock = ^(GDTCORUploadPackage *_Nonnull package) {
    [package completeDelivery];
    uploadAttempts++;
  };
  [GDTCORUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
  [GDTCORUploadCoordinator sharedInstance].timerLeeway = 0;

  [[GDTCORUploadCoordinator sharedInstance] startTimer];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  dispatch_sync([GDTCORUploadCoordinator sharedInstance].coordinationQueue, ^{
    // More than two attempts should have been made.
    XCTAssertGreaterThan(uploadAttempts, 2);
  });
}

/** Tests the situation in which the uploader failed to upload the events for some reason. */
- (void)testThatAFailedUploadResultsInAnEventualRetry {
  __block int uploadAttempts = 0;
  self.prioritizer.events = [GDTCOREventGenerator generate3StoredEvents];
  self.uploader.uploadPackageBlock = ^(GDTCORUploadPackage *_Nonnull package) {
    [package retryDeliveryInTheFuture];
    uploadAttempts++;
  };
  [GDTCORUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC / 10;
  [GDTCORUploadCoordinator sharedInstance].timerLeeway = 0;

  [[GDTCORUploadCoordinator sharedInstance] startTimer];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  dispatch_sync([GDTCORUploadCoordinator sharedInstance].coordinationQueue, ^{
    // More than two attempts should have been made.
    XCTAssertGreaterThan(uploadAttempts, 2);
  });
}

/** Tests that encoding and decoding works without crashing. */
- (void)testNSSecureCoding {
  GDTCORUploadPackage *package = [[GDTCORUploadPackage alloc] initWithTarget:kGDTCORTargetTest];
  GDTCORUploadCoordinator *coordinator = [[GDTCORUploadCoordinator alloc] init];
  coordinator.targetToInFlightPackages[@(kGDTCORTargetTest)] = package;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:coordinator];

  // Unarchiving the coordinator always ends up altering the singleton instance.
  GDTCORUploadCoordinator *unarchivedCoordinator = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  XCTAssertEqualObjects([GDTCORUploadCoordinator sharedInstance], unarchivedCoordinator);
}

@end

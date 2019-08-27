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

#import "GDTTests/Unit/GDTTestCase.h"

#import "GDTLibrary/Private/GDTUploadCoordinator.h"

#import "GDTTests/Common/Categories/GDTRegistrar+Testing.h"
#import "GDTTests/Common/Categories/GDTUploadCoordinator+Testing.h"

#import "GDTTests/Common/Fakes/GDTStorageFake.h"

#import "GDTTests/Unit/Helpers/GDTEventGenerator.h"
#import "GDTTests/Unit/Helpers/GDTTestPrioritizer.h"
#import "GDTTests/Unit/Helpers/GDTTestUploadPackage.h"
#import "GDTTests/Unit/Helpers/GDTTestUploader.h"

@interface GDTUploadCoordinatorTest : GDTTestCase

/** A storage fake to inject into GDTUploadCoordinator. */
@property(nonatomic) GDTStorageFake *storageFake;

/** A test prioritizer. */
@property(nonatomic) GDTTestPrioritizer *prioritizer;

/** A test uploader. */
@property(nonatomic) GDTTestUploader *uploader;

@end

@implementation GDTUploadCoordinatorTest

- (void)setUp {
  [super setUp];
  self.storageFake = [[GDTStorageFake alloc] init];
  self.prioritizer = [[GDTTestPrioritizer alloc] init];
  self.uploader = [[GDTTestUploader alloc] init];

  [[GDTRegistrar sharedInstance] registerPrioritizer:_prioritizer target:kGDTTargetTest];
  [[GDTRegistrar sharedInstance] registerUploader:_uploader target:kGDTTargetTest];

  GDTUploadCoordinator *uploadCoordinator = [GDTUploadCoordinator sharedInstance];
  uploadCoordinator.storage = self.storageFake;
  uploadCoordinator.timerInterval = NSEC_PER_SEC;
  uploadCoordinator.timerLeeway = 0;
}

- (void)tearDown {
  [super tearDown];
  [[GDTUploadCoordinator sharedInstance] reset];
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
  self.prioritizer.events = [GDTEventGenerator generate3StoredEvents];
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadPackageBlock = ^(GDTUploadPackage *_Nonnull package) {
    [expectation fulfill];
  };
  XCTAssertNoThrow([[GDTUploadCoordinator sharedInstance] forceUploadForTarget:kGDTTargetTest]);
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests the timer is running at the desired frequency. */
- (void)testTimerIsRunningAtDesiredFrequency {
  __block int numberOfTimesCalled = 0;
  self.prioritizer.uploadPackageWithConditionsBlock = ^{
    numberOfTimesCalled++;
  };
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    // Timer should fire 1 times a second.
    [GDTUploadCoordinator sharedInstance].timerInterval = NSEC_PER_SEC;
    [GDTUploadCoordinator sharedInstance].timerLeeway = 0;
  });
  [[GDTUploadCoordinator sharedInstance] startTimer];

  // Run for 5 seconds.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];

  // It's expected that the timer called the prioritizer 5 times +/- 1 during that 1 second + the
  // coordinator running before that.
  dispatch_sync([GDTUploadCoordinator sharedInstance].coordinationQueue, ^{
    XCTAssertGreaterThan(numberOfTimesCalled, 4);  // Some latency is expected on a busy system.
  });
}

/** Tests uploading events via the coordinator timer. */
- (void)testUploadingEventsViaTimer {
  __block int uploadAttempts = 0;
  self.prioritizer.events = [GDTEventGenerator generate3StoredEvents];
  self.uploader.uploadPackageBlock = ^(GDTUploadPackage *_Nonnull package) {
    [package completeDelivery];
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
  self.prioritizer.events = [GDTEventGenerator generate3StoredEvents];
  self.uploader.uploadPackageBlock = ^(GDTUploadPackage *_Nonnull package) {
    [package retryDeliveryInTheFuture];
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

/** Tests that encoding and decoding works without crashing. */
- (void)testNSSecureCoding {
  GDTUploadPackage *package = [[GDTUploadPackage alloc] initWithTarget:kGDTTargetTest];
  GDTUploadCoordinator *coordinator = [[GDTUploadCoordinator alloc] init];
  coordinator.targetToInFlightPackages[@(kGDTTargetTest)] = package;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:coordinator];

  // Unarchiving the coordinator always ends up altering the singleton instance.
  GDTUploadCoordinator *unarchivedCoordinator = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  XCTAssertEqualObjects([GDTUploadCoordinator sharedInstance], unarchivedCoordinator);
}

@end

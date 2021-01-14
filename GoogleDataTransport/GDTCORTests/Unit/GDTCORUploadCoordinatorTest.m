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

#import "GoogleDataTransport/GDTCORTests/Unit/GDTCORTestCase.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORPlatform.h"

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORFlatFileStorage.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORUploadCoordinator+Testing.h"

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORStorageFake.h"

#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCOREventGenerator.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

@interface GDTCORUploadCoordinatorTest : GDTCORTestCase

/** A storage fake to inject into GDTCORUploadCoordinator. */
@property(nonatomic) GDTCORStorageFake *storageFake;

/** A test uploader. */
@property(nonatomic) GDTCORTestUploader *uploader;

@end

@implementation GDTCORUploadCoordinatorTest

- (void)setUp {
  [super setUp];
  self.storageFake = [[GDTCORStorageFake alloc] init];
  self.uploader = [[GDTCORTestUploader alloc] init];

  [[GDTCORRegistrar sharedInstance] registerUploader:_uploader target:kGDTCORTargetTest];

  GDTCORUploadCoordinator *uploadCoordinator = [GDTCORUploadCoordinator sharedInstance];
  [[GDTCORRegistrar sharedInstance] registerStorage:self.storageFake target:kGDTCORTargetTest];
  uploadCoordinator.timerInterval = NSEC_PER_SEC;
  uploadCoordinator.timerLeeway = 0;
}

- (void)tearDown {
  [super tearDown];
  [[GDTCORUploadCoordinator sharedInstance] reset];
  [[GDTCORRegistrar sharedInstance] reset];
  self.storageFake = nil;
  self.uploader = nil;
}

/** Tests the default initializer. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTCORUploadCoordinator sharedInstance],
                 [GDTCORUploadCoordinator sharedInstance]);
}

/** Tests that forcing a event upload works. */
- (void)testForceUploadEvents {
  XCTestExpectation *expectation = [self expectationWithDescription:@"uploader will upload"];
  self.uploader.uploadWithConditionsBlock =
      ^(GDTCORTarget target, GDTCORUploadConditions conditions) {
        [expectation fulfill];
      };
  XCTAssertNoThrow(
      [[GDTCORUploadCoordinator sharedInstance] forceUploadForTarget:kGDTCORTargetTest]);
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests the timer is running at the desired frequency. */
- (void)testTimerIsRunningAtDesiredFrequency {
  __block int numberOfTimesCalled = 0;
  self.uploader.uploadWithConditionsBlock =
      ^(GDTCORTarget target, GDTCORUploadConditions conditions) {
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

/** Tests the situation in which the uploader failed to upload the events for some reason. */
- (void)testThatAFailedUploadResultsInAnEventualRetry {
  id<GDTCORStorageProtocol> storage = self.storageFake;
  __block int uploadAttempts = 0;
  [[GDTCOREventGenerator generate3Events]
      enumerateObjectsUsingBlock:^(GDTCOREvent *_Nonnull obj, BOOL *_Nonnull stop) {
        [self.storageFake storeEvent:obj onComplete:nil];
      }];
  __block NSNumber *batchID;
  [storage
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:600.0]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable events) {
                    batchID = newBatchID;
                  }];
  self.uploader.uploadWithConditionsBlock =
      ^(GDTCORTarget target, GDTCORUploadConditions conditions) {
        [storage removeBatchWithID:batchID deleteEvents:NO onComplete:nil];
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

@end

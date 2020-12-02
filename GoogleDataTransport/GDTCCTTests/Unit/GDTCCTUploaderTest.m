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

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORStorageProtocol.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTNanopbHelpers.h"
#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploader.h"

#import "GoogleDataTransport/GDTCCTTests/Common/TestStorage/GDTCCTTestStorage.h"

#import "GoogleDataTransport/GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"
#import "GoogleDataTransport/GDTCCTTests/Unit/TestServer/GDTCCTTestServer.h"

@interface GDTCCTUploaderTest : XCTestCase

@property(nonatomic) GDTCCTUploader *uploader;

/** An event generator for testing. */
@property(nonatomic) GDTCCTEventGenerator *generator;

/** The local HTTP server to use for testing. */
@property(nonatomic) GDTCCTTestServer *testServer;

@property(nonatomic) GDTCCTTestStorage *testStorage;

@end

@implementation GDTCCTUploaderTest

- (void)setUp {
  [super setUp];

  self.testStorage = [[GDTCCTTestStorage alloc] init];

  // Reset registrar to avoid real object access storage along with the tests.
  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORRegistrar sharedInstance] registerStorage:self.testStorage target:kGDTCORTargetTest];

  self.generator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetTest];

  self.testServer = [[GDTCCTTestServer alloc] init];
  [self.testServer registerLogBatchPath];
  [self.testServer start];
  XCTAssertTrue(self.testServer.isRunning);

  self.uploader = [[GDTCCTUploader alloc] init];
  GDTCCTUploader.testServerURL =
      [self.testServer.serverURL URLByAppendingPathComponent:@"logBatch"];
}

- (void)tearDown {
  self.testServer.responseCompletedBlock = nil;
  [self.testServer stop];
  self.testStorage = nil;
  [super tearDown];
}

#pragma mark - Upload flow tests

- (void)testUploadURLsAreCorrect {
  GDTCCTUploader.testServerURL = nil;
  NSDictionary<NSNumber *, NSURL *> *URLs = GDTCCTUploader.uploadURLs;
  XCTAssertEqualObjects(URLs[@(kGDTCORTargetCCT)], [self serverURLForTarget:kGDTCORTargetCCT]);
  XCTAssertEqualObjects(URLs[@(kGDTCORTargetFLL)], [self serverURLForTarget:kGDTCORTargetFLL]);
  XCTAssertEqualObjects(URLs[@(kGDTCORTargetCSH)], [self serverURLForTarget:kGDTCORTargetCSH]);
  XCTAssertEqualObjects(URLs[@(kGDTCORTargetINT)], [self serverURLForTarget:kGDTCORTargetINT]);
  GDTCCTUploader.testServerURL =
      [self.testServer.serverURL URLByAppendingPathComponent:@"logBatch"];
}

- (void)testUploadTargetWhenThereAreEventsToUpload {
  // 0. Generate test events.
  id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(kGDTCORTargetTest);
  XCTAssertNotNil(storage);
  [[self.generator generateTheFiveConsistentEvents]
      enumerateObjectsUsingBlock:^(GDTCOREvent *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [storage storeEvent:obj onComplete:nil];
      }];

  // 1. Set up expectations.
  // 1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  XCTestExpectation *hasEventsExpectation = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                           result:YES];

  // 1.3. Don't expect previously batched events to be removed (no batch present).
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;

  // 1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 2. Create uploader and start upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:YES];

  // 4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

- (void)testUploadTargetWhenThereIsStoredBatchThenItIsUploadedFirst {
  // 0. Generate test events.
  // 0.1. Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];
  // 0.2. Batch the event.
  [self batchEvents];

  // 1. Set up expectations.
  // 1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  XCTestExpectation *hasEventsExpectation = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                           result:YES];

  // 1.3. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 2. Create uploader and start upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:NO];

  // 4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

/** Tests that when there is an ongoing upload no other uploads are started until the 1st finishes.
 * Once 1st finished, another one can be started. */
- (void)testUploadTargetWhenThereIsOngoingUploadThenNoOp {
  // 0. Set up expectations to track 1st upload progress.
  // 0.1. Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];
  // 0.2. Configure server request expectation.
  // Block to call to finish the 1st request.
  __block dispatch_block_t requestCompletionBlock;
  __auto_type __weak weakSelf = self;
  XCTestExpectation *serverRequestExpectation1 =
      [self expectationWithDescription:@"serverRequestExpectation1"];
  self.testServer.requestHandler =
      ^(GCDWebServerRequest *_Nonnull request, GCDWebServerResponse *_Nullable suggestedResponse,
        GCDWebServerCompletionBlock _Nonnull completionBlock) {
        weakSelf.testServer.requestHandler = nil;
        requestCompletionBlock = ^{
          completionBlock(suggestedResponse);
        };

        [serverRequestExpectation1 fulfill];
      };

  // 0.3. Configure storage.
  XCTestExpectation *hasEventsExpectation1 = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                            result:YES];

  // 0.4. Start upload 1st upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 0.4. Wait for server request to be sent.
  [self waitForExpectations:@[ hasEventsExpectation1, serverRequestExpectation1 ] timeout:1];

  // 1. Test 2nd request.
  // 1.0 Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];

  // 1.1. Configure expectations for the 2nd request.
  // 1.1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.1.2. Don't expect any storage.
  self.testStorage.batchIDsForTargetExpectation.inverted = YES;
  self.testStorage.batchWithEventSelectorExpectation.inverted = YES;
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;
  self.testStorage.removeBatchAndDeleteEventsExpectation.inverted = YES;

  XCTestExpectation *hasEventsExpectation2 = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                            result:YES];
  hasEventsExpectation2.inverted = YES;

  // 1.2. Start upload 2nd time.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 1.3. Wait for expectations.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation, hasEventsExpectation2,
    self.testStorage.batchWithEventSelectorExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3];

  // 1.4. Wait for 1st upload finish.
  requestCompletionBlock();
  [self waitForUploadOperationsToFinish:self.uploader];

  // 3. Test another upload after the 1st finished.
  // 3.1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 3.1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  XCTestExpectation *hasEventsExpectation3 = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                            result:YES];

  // 3.1.3. Don't expect previously batched events to be removed (no batch present).
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;

  // 3.1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 3.3.2. Start 3rd upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 3.3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation3,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:YES];

  // 3.4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

- (void)testUploadTarget_WhenThereAreBothStoredBatchAndEvents_ThenRemoveBatchAndBatchThenAllEvents {
  // 0. Generate test events.
  // 0.1. Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];
  // 0.2. Batch the event.
  [self batchEvents];
  // 0.3. Generate one more event.
  [self.generator generateEvent:GDTCOREventQoSFast];

  // 1. Set up expectations.
  // 1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  XCTestExpectation *hasEventsExpectation = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                           result:YES];

  // 1.3. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 1.2. Start upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 1.3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:YES];

  // 1.4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

- (void)testUploadTarget_WhenThereAreNoEventsFirstThenEventsAdded_ThenUploadNewEvent {
  GDTCCTUploader.testServerURL =
      [self.testServer.serverURL URLByAppendingPathComponent:@"logBatch"];

  // 1. Test stored batch upload.
  // 1.1. Set up expectations.
  // 1.1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  XCTestExpectation *hasEventsExpectation = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                           result:NO];

  // 1.1.3. Don't expect events to be batched or deleted.
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;
  self.testStorage.removeBatchAndDeleteEventsExpectation.inverted = YES;
  self.testStorage.batchWithEventSelectorExpectation.inverted = YES;

  // 1.1.4. Don't expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation1 = [self expectationTestServerSuccessRequestResponse];
  responseSentExpectation1.inverted = YES;

  // 1.2. Create uploader and start upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 1.3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation1,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:YES];

  // 1.4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];

  // 2. Test stored events upload.
  // 2.0. Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];

  // 2.1. Set up expectations.
  // 2.1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 2.1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  hasEventsExpectation = [self expectStorageHasEventsForTarget:kGDTCORTargetTest result:YES];

  // 2.1.3. Don't expect previously batched events to be removed (no batch present).
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;

  // 2.1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 2.2. Create uploader and start upload.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 2.3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:YES];

  // 2.4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

#pragma mark - Storage interaction tests

- (void)testStorageSelectorWhenConditionsHighPriority {
  __weak id weakSelf = self;
  [self assertStorageSelectorWithCondition:GDTCORUploadConditionHighPriority
                           validationBlock:^(GDTCORStorageEventSelector *_Nullable eventSelector,
                                             NSDate *expiration) {
                             __unused id self = weakSelf;
                             XCTAssertLessThan([expiration timeIntervalSinceNow], 600);
                             XCTAssertEqual(eventSelector.selectedTarget, kGDTCORTargetTest);
                             XCTAssertNil(eventSelector.selectedEventIDs);
                             XCTAssertNil(eventSelector.selectedMappingIDs);
                             XCTAssertNil(eventSelector.selectedQosTiers);
                           }];
}

- (void)testStorageSelectorWhenConditionsMobileData {
  __weak id weakSelf = self;
  [self
      assertStorageSelectorWithCondition:GDTCORUploadConditionMobileData
                         validationBlock:^(GDTCORStorageEventSelector *_Nullable eventSelector,
                                           NSDate *expiration) {
                           __unused id self = weakSelf;
                           XCTAssertLessThan([expiration timeIntervalSinceNow], 600);
                           XCTAssertEqual(eventSelector.selectedTarget, kGDTCORTargetTest);
                           XCTAssertNil(eventSelector.selectedEventIDs);
                           XCTAssertNil(eventSelector.selectedMappingIDs);

                           NSSet *expectedQoSTiers = [NSSet
                               setWithArray:@[ @(GDTCOREventQoSFast), @(GDTCOREventQosDefault) ]];
                           XCTAssertEqualObjects(eventSelector.selectedQosTiers, expectedQoSTiers);
                         }];
}

- (void)testStorageSelectorWhenConditionsWifiData {
  __weak id weakSelf = self;
  [self
      assertStorageSelectorWithCondition:GDTCORUploadConditionWifiData
                         validationBlock:^(GDTCORStorageEventSelector *_Nullable eventSelector,
                                           NSDate *expiration) {
                           __unused id self = weakSelf;
                           XCTAssertLessThan([expiration timeIntervalSinceNow], 600);
                           XCTAssertEqual(eventSelector.selectedTarget, kGDTCORTargetTest);
                           XCTAssertNil(eventSelector.selectedEventIDs);
                           XCTAssertNil(eventSelector.selectedMappingIDs);

                           NSSet *expectedQoSTiers = [NSSet setWithArray:@[
                             @(GDTCOREventQoSFast), @(GDTCOREventQoSWifiOnly),
                             @(GDTCOREventQosDefault), @(GDTCOREventQoSTelemetry),
                             @(GDTCOREventQoSUnknown)
                           ]];
                           XCTAssertEqualObjects(eventSelector.selectedQosTiers, expectedQoSTiers);
                         }];
}

#pragma mark - Test ready for upload based on conditions

- (void)testUploadTarget_WhenNoConnection_ThenDoNotUpload {
  // 0. Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];

  // 1. Configure expectations for the 2nd request.
  // 1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.2. Don't expect any storage.
  self.testStorage.batchIDsForTargetExpectation.inverted = YES;
  self.testStorage.batchWithEventSelectorExpectation.inverted = YES;
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;
  self.testStorage.removeBatchAndDeleteEventsExpectation.inverted = YES;

  XCTestExpectation *hasEventsExpectation2 = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                            result:YES];
  hasEventsExpectation2.inverted = YES;

  // 2. Start upload 2nd time.
  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionNoNetwork];

  // 3. Wait for expectations.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation, hasEventsExpectation2,
    self.testStorage.batchWithEventSelectorExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3];

  // 4. Wait for 1st upload finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

- (void)testUploadTarget_WhenBeforeServerNextUploadTimeForCCTAndFLLTargets_ThenDoNotUpload {
  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetCCT
                                                  QoS:GDTCOREventQoSFast
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:NO];

  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetFLL
                                                  QoS:GDTCOREventQosDefault
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:NO];
}

- (void)
    testUploadTarget_WhenBeforeServerNextUploadTimeForCCTAndFLLTargetsAndHighPriority_ThenUpload {
  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetCCT
                                                  QoS:GDTCOREventQoSFast
                                           conditions:GDTCORUploadConditionHighPriority
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:YES];

  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetFLL
                                                  QoS:GDTCOREventQosDefault
                                           conditions:GDTCORUploadConditionHighPriority
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:YES];
}

- (void)testUploadTarget_WhenBeforeServerNextUploadTimeForOtherTargets_ThenUpload {
  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetTest
                                                  QoS:GDTCOREventQoSFast
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:YES];

  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetCSH
                                                  QoS:GDTCOREventQosDefault
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:YES];

  [self assertUploadTargetRespectsNextRequestWaitTime:60
                                            forTarget:kGDTCORTargetINT
                                                  QoS:GDTCOREventQosDefault
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:NO
                                        expectRequest:YES];
}

- (void)testUploadTarget_WhenAfterServerNextUploadTimeForCCTAndFLLTargets_ThenUpload {
  [self assertUploadTargetRespectsNextRequestWaitTime:1
                                            forTarget:kGDTCORTargetCCT
                                                  QoS:GDTCOREventQoSFast
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:YES
                                        expectRequest:YES];

  [self assertUploadTargetRespectsNextRequestWaitTime:1
                                            forTarget:kGDTCORTargetFLL
                                                  QoS:GDTCOREventQosDefault
                                           conditions:GDTCORUploadConditionWifiData
                         shouldWaitForNextRequestTime:YES
                                        expectRequest:YES];
}

//// TODO: Tests for uploading several empty targets and then non-empty target.

#pragma mark - Helpers

- (NSNumber *)batchEvents {
  XCTestExpectation *eventsBatched = [self expectationWithDescription:@"eventsBatched"];
  __block NSNumber *batchID;
  [self.testStorage
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate distantFuture]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable batchEvents) {
                    [eventsBatched fulfill];
                    batchID = newBatchID;
                  }];
  [self waitForExpectations:@[ eventsBatched ] timeout:0.5];

  XCTAssertNotNil(batchID);
  return batchID;
}

- (XCTestExpectation *)expectationTestServerSuccessRequestResponse {
  __weak id weakSelf = self;
  XCTestExpectation *responseSentExpectation = [self expectationWithDescription:@"response sent"];

  self.testServer.responseCompletedBlock =
      ^(GCDWebServerRequest *_Nonnull request, GCDWebServerResponse *_Nonnull response) {
        // Redefining the self var addresses strong self capturing in the XCTAssert macros.
        id self = weakSelf;
        XCTAssertNotNil(self);
        [responseSentExpectation fulfill];
        XCTAssertEqual(response.statusCode, 200);
        XCTAssertTrue(response.hasBody);
      };
  return responseSentExpectation;
}

- (void)setUpStorageExpectations {
  self.testStorage.batchIDsForTargetExpectation =
      [self expectationWithDescription:@"batchIDsForTargetExpectation"];
  self.testStorage.batchWithEventSelectorExpectation =
      [self expectationWithDescription:@"batchWithEventSelectorExpectation"];
  self.testStorage.removeBatchWithoutDeletingEventsExpectation =
      [self expectationWithDescription:@"removeBatchWithoutDeletingEventsExpectation"];
  self.testStorage.removeBatchAndDeleteEventsExpectation =
      [self expectationWithDescription:@"removeBatchAndDeleteEventsExpectation"];
}

- (void)waitForUploadOperationsToFinish:(GDTCCTUploader *)uploader {
  XCTestExpectation *uploadFinishedExpectation =
      [self expectationWithDescription:@"uploadFinishedExpectation"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                 uploader.uploaderQueue, ^{
                   [uploadFinishedExpectation fulfill];
                   XCTAssertNil(uploader.currentTask);
                 });
  [self waitForExpectations:@[ uploadFinishedExpectation ] timeout:1];
}

- (XCTestExpectation *)expectStorageHasEventsForTarget:(GDTCORTarget)expectedTarget
                                                result:(BOOL)hasEvents {
  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];

  __weak __auto_type weakSelf = self;
  self.testStorage.hasEventsForTargetHandler =
      ^(GDTCORTarget target, GDTCCTTestStorageHasEventsCompletion _Nonnull completion) {
        __unused __auto_type self = weakSelf;
        [expectation fulfill];
        XCTAssertEqual(target, expectedTarget);
        completion(hasEvents);
      };

  return expectation;
}

- (void)assertStorageSelectorWithCondition:(GDTCORUploadConditions)conditions
                           validationBlock:(void (^)(GDTCORStorageEventSelector *_Nullable selector,
                                                     NSDate *expirationDate))validationBlock {
  XCTestExpectation *hasEventsExpectation = [self expectStorageHasEventsForTarget:kGDTCORTargetTest
                                                                           result:YES];

  XCTestExpectation *storageBatchExpectation =
      [self expectationWithDescription:@"storageBatchExpectation"];

  self.testStorage.batchWithEventSelectorHandler =
      ^(GDTCORStorageEventSelector *_Nullable eventSelector, NSDate *_Nullable expiration,
        GDTCORStorageBatchBlock _Nullable completion) {
        // Redefining the self var addresses strong self capturing in the XCTAssert macros.
        [storageBatchExpectation fulfill];

        validationBlock(eventSelector, expiration);
        completion(nil, nil);
      };

  [self.uploader uploadTarget:kGDTCORTargetTest withConditions:conditions];

  [self waitForExpectations:@[ hasEventsExpectation, storageBatchExpectation ] timeout:1];
}

- (void)sendEventSuccessfully {
  // 0. Generate test events.
  [self.generator generateEvent:GDTCOREventQoSFast];

  // 1. Set up expectations.
  // 1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];

  // 1.2. Expect `hasEventsForTarget:onComplete:` to be called.
  XCTestExpectation *hasEventsExpectation =
      [self expectStorageHasEventsForTarget:self.generator.target result:YES];

  // 1.3. Don't expect previously batched events to be removed (no batch present).
  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;

  // 1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 2. Create uploader and start upload.
  [self.uploader uploadTarget:self.generator.target withConditions:GDTCORUploadConditionWifiData];

  // 3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation, hasEventsExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3
               enforceOrder:YES];

  // 4. Wait for upload operation to finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

- (void)assertUploadTargetRespectsNextRequestWaitTime:(NSTimeInterval)nextRequestWaitTime
                                            forTarget:(GDTCORTarget)target
                                                  QoS:(GDTCOREventQoS)eventQoS
                                           conditions:(GDTCORUploadConditions)conditions
                         shouldWaitForNextRequestTime:(BOOL)shouldWaitForNextRequestTime
                                        expectRequest:(BOOL)expectRequest {
  // 0.1. Set response next request wait time.
  self.testServer.responseNextRequestWaitTime = nextRequestWaitTime;
  // 0.2. Use a target that should respect next upload time.
  self.generator = [[GDTCCTEventGenerator alloc] initWithTarget:target];
  // 0.3. Register storage for the target.
  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORRegistrar sharedInstance] registerStorage:self.testStorage target:self.generator.target];
  // 0.4. Send an event and receive response.
  [self sendEventSuccessfully];
  // 0.5. Generate another event to be sent.
  [self.generator generateEvent:eventQoS];

  // 0.6. Wait for the next request time.
  if (shouldWaitForNextRequestTime) {
    [[NSRunLoop currentRunLoop]
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:nextRequestWaitTime + 0.5]];
  }

  // 1. Configure expectations for the 2nd request.
  // 1.1. Set up all relevant storage expectations.
  [self setUpStorageExpectations];
  XCTestExpectation *hasEventsExpectation2 =
      [self expectStorageHasEventsForTarget:self.generator.target result:YES];

  // 1.2. Upload response expectation.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 1.3. Invert expectations if no actions expected.
  if (!expectRequest) {
    self.testStorage.batchIDsForTargetExpectation.inverted = YES;
    self.testStorage.batchWithEventSelectorExpectation.inverted = YES;
    self.testStorage.removeBatchAndDeleteEventsExpectation.inverted = YES;
    hasEventsExpectation2.inverted = YES;
    responseSentExpectation.inverted = YES;
  }

  self.testStorage.removeBatchWithoutDeletingEventsExpectation.inverted = YES;

  // 2. Start upload 2nd time.
  [self.uploader uploadTarget:self.generator.target withConditions:conditions];

  // 3. Wait for expectations.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation, hasEventsExpectation2,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchWithoutDeletingEventsExpectation,
    self.testStorage.removeBatchAndDeleteEventsExpectation
  ]
                    timeout:3];

  // 4. Wait for 1st upload finish.
  [self waitForUploadOperationsToFinish:self.uploader];
}

- (nullable NSURL *)serverURLForTarget:(GDTCORTarget)target {
  // These strings should be interleaved to construct the real URL. This is just to (hopefully)
  // fool github URL scanning bots.
  static NSURL *CCTServerURL;
  static NSString *const kINTServerURL =
      @"https://dummyapiverylong-dummy.dummy.com/dummy/api/very/long";
  static dispatch_once_t CCTOnceToken;
  dispatch_once(&CCTOnceToken, ^{
    const char *p1 = "hts/frbslgiggolai.o/0clgbth";
    const char *p2 = "tp:/ieaeogn.ogepscmvc/o/ac";
    const char URL[54] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],  p1[4],
                          p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],  p1[8],  p2[8],
                          p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11], p1[12], p2[12], p1[13],
                          p2[13], p1[14], p2[14], p1[15], p2[15], p1[16], p2[16], p1[17], p2[17],
                          p1[18], p2[18], p1[19], p2[19], p1[20], p2[20], p1[21], p2[21], p1[22],
                          p2[22], p1[23], p2[23], p1[24], p2[24], p1[25], p2[25], p1[26], '\0'};
    CCTServerURL = [NSURL URLWithString:[NSString stringWithUTF8String:URL]];
  });

  static NSURL *FLLServerURL;
  static dispatch_once_t FLLOnceToken;
  dispatch_once(&FLLOnceToken, ^{
    const char *p1 = "hts/frbslgigp.ogepscmv/ieo/eaybtho";
    const char *p2 = "tp:/ieaeogn-agolai.o/1frlglgc/aclg";
    const char URL[69] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],  p1[4],
                          p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],  p1[8],  p2[8],
                          p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11], p1[12], p2[12], p1[13],
                          p2[13], p1[14], p2[14], p1[15], p2[15], p1[16], p2[16], p1[17], p2[17],
                          p1[18], p2[18], p1[19], p2[19], p1[20], p2[20], p1[21], p2[21], p1[22],
                          p2[22], p1[23], p2[23], p1[24], p2[24], p1[25], p2[25], p1[26], p2[26],
                          p1[27], p2[27], p1[28], p2[28], p1[29], p2[29], p1[30], p2[30], p1[31],
                          p2[31], p1[32], p2[32], p1[33], p2[33], '\0'};
    FLLServerURL = [NSURL URLWithString:[NSString stringWithUTF8String:URL]];
  });

  static NSURL *CSHServerURL;
  static dispatch_once_t CSHOnceToken;
  dispatch_once(&CSHOnceToken, ^{
    // These strings should be interleaved to construct the real URL. This is just to (hopefully)
    // fool github URL scanning bots.
    const char *p1 = "hts/cahyiseot-agolai.o/1frlglgc/aclg";
    const char *p2 = "tp:/rsltcrprsp.ogepscmv/ieo/eaybtho";
    const char URL[72] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],  p1[4],
                          p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],  p1[8],  p2[8],
                          p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11], p1[12], p2[12], p1[13],
                          p2[13], p1[14], p2[14], p1[15], p2[15], p1[16], p2[16], p1[17], p2[17],
                          p1[18], p2[18], p1[19], p2[19], p1[20], p2[20], p1[21], p2[21], p1[22],
                          p2[22], p1[23], p2[23], p1[24], p2[24], p1[25], p2[25], p1[26], p2[26],
                          p1[27], p2[27], p1[28], p2[28], p1[29], p2[29], p1[30], p2[30], p1[31],
                          p2[31], p1[32], p2[32], p1[33], p2[33], p1[34], p2[34], p1[35], '\0'};
    CSHServerURL = [NSURL URLWithString:[NSString stringWithUTF8String:URL]];
  });

  switch (target) {
    case kGDTCORTargetCCT:
      return CCTServerURL;

    case kGDTCORTargetFLL:
      return FLLServerURL;

    case kGDTCORTargetCSH:
      return CSHServerURL;

    case kGDTCORTargetINT:
      return [NSURL URLWithString:kINTServerURL];

    default:
      return nil;
      break;
  }
}

@end

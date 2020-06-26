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

#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCORRegistrar.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCORStorageProtocol.h"

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTNanopbHelpers.h"
#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploader.h"

#import "GoogleDataTransport/GDTCCTTests/Common/TestStorage/GDTCCTTestStorage.h"

#import "GoogleDataTransport/GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"
#import "GoogleDataTransport/GDTCCTTests/Unit/TestServer/GDTCCTTestServer.h"

@interface GDTCCTUploaderTest : XCTestCase

/** An event generator for testing. */
@property(nonatomic) GDTCCTEventGenerator *generator;

/** The local HTTP server to use for testing. */
@property(nonatomic) GDTCCTTestServer *testServer;

@property(nonatomic) GDTCCTTestStorage *testStorage;

@end

@implementation GDTCCTUploaderTest

- (void)setUp {
  self.testStorage = [[GDTCCTTestStorage alloc] init];
  [[GDTCORRegistrar sharedInstance] registerStorage:self.testStorage target:kGDTCORTargetTest];
  self.generator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetTest];
  self.testServer = [[GDTCCTTestServer alloc] init];
  [self.testServer registerLogBatchPath];
  [self.testServer start];
  XCTAssertTrue(self.testServer.isRunning);
}

- (void)tearDown {
  [self.testServer stop];
  self.testStorage = nil;
  [super tearDown];
}

- (void)testCCTUploadGivenConditions {
  // 0. Generate test events.
  id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(kGDTCORTargetTest);
  XCTAssertNotNil(storage);
  [[self.generator generateTheFiveConsistentEvents]
      enumerateObjectsUsingBlock:^(GDTCOREvent *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [storage storeEvent:obj onComplete:nil];
      }];

  // 1. Set up expectations.
  // 1.1. Expect batch IDs to be requested.
  self.testStorage.batchIDsForTargetExpectation =
      [self expectationWithDescription:@"batchIDsForTargetExpectation"];

  // 1.2. Don't expect previously batched events to be requested.
  self.testStorage.eventsInBatchWithIDExpectation =
      [self expectationWithDescription:@"eventsInBatchWithIDExpectation"];
  self.testStorage.eventsInBatchWithIDExpectation.inverted = YES;

  // 1.3. Expect events batched.
  self.testStorage.batchWithEventSelectorExpectation =
      [self expectationWithDescription:@"batchWithEventSelectorExpectation"];

  // 1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 1.5. Expect batch to be removed.
  self.testStorage.removeBatchWithIDExpectation =
      [self expectationWithDescription:@"removeBatchWithIDExpectation"];

  // 2. Create uploader and start upload.
  GDTCCTUploader *uploader = [[GDTCCTUploader alloc] init];
  uploader.testServerURL = [self.testServer.serverURL URLByAppendingPathComponent:@"logBatch"];
  [uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation, self.testStorage.eventsInBatchWithIDExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchWithIDExpectation
  ]
                    timeout:5
               enforceOrder:YES];

  // 4. Wait for upload operation to finish.
  XCTestExpectation *uploadFinishedExpectation =
      [self expectationWithDescription:@"uploadFinishedExpectation"];
  dispatch_sync(uploader.uploaderQueue, ^{
    [uploadFinishedExpectation fulfill];
    XCTAssertNil(uploader.currentTask);
  });
  [self waitForExpectations:@[ uploadFinishedExpectation ] timeout:0.5];
}

- (void)testUploadTargetWhenThereIsStoredBatchThenItIsUploadedFirst {
  // 0. Generate test events.
  // 0.1. Generate and store and an event.
  [self.generator generateEvent:GDTCOREventQoSFast];
  // 0.2. Batch the event.
  [self batchEvents];

  // 1. Set up expectations.
  // 1.1. Expect batch IDs to be requested.
  self.testStorage.batchIDsForTargetExpectation =
      [self expectationWithDescription:@"batchIDsForTargetExpectation"];

  // 1.2. Expect previously batched events to be requested.
  self.testStorage.eventsInBatchWithIDExpectation =
      [self expectationWithDescription:@"eventsInBatchWithIDExpectation"];

  // 1.3. Don't Expect events batched.
  self.testStorage.batchWithEventSelectorExpectation =
      [self expectationWithDescription:@"batchWithEventSelectorExpectation"];
  self.testStorage.batchWithEventSelectorExpectation.inverted = YES;

  // 1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 1.5. Expect batch to be removed.
  self.testStorage.removeBatchWithIDExpectation =
      [self expectationWithDescription:@"removeBatchWithIDExpectation"];

  // 2. Create uploader and start upload.
  GDTCCTUploader *uploader = [[GDTCCTUploader alloc] init];
  uploader.testServerURL = [self.testServer.serverURL URLByAppendingPathComponent:@"logBatch"];
  [uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation, self.testStorage.eventsInBatchWithIDExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchWithIDExpectation
  ]
                    timeout:50
               enforceOrder:YES];

  // 4. Wait for upload operation to finish.
  XCTestExpectation *uploadFinishedExpectation =
      [self expectationWithDescription:@"uploadFinishedExpectation"];
  dispatch_sync(uploader.uploaderQueue, ^{
    [uploadFinishedExpectation fulfill];
    XCTAssertNil(uploader.currentTask);
  });
  [self waitForExpectations:@[ uploadFinishedExpectation ] timeout:0.5];
}

- (void)testUploadTargetWhenThereIsOngoingUploadThenNoOp {
  // 1. Set up expectations.
  // 1.1. Expect batch IDs to be requested.
  self.testStorage.batchIDsForTargetExpectation =
      [self expectationWithDescription:@"batchIDsForTargetExpectation"];

  // 1.2. Don't expect previously batched events to be requested.
  self.testStorage.eventsInBatchWithIDExpectation =
      [self expectationWithDescription:@"eventsInBatchWithIDExpectation"];
  self.testStorage.eventsInBatchWithIDExpectation.inverted = YES;

  // 1.3. Expect events batched.
  self.testStorage.batchWithEventSelectorExpectation =
      [self expectationWithDescription:@"batchWithEventSelectorExpectation"];

  // 1.4. Expect a batch to be uploaded.
  XCTestExpectation *responseSentExpectation = [self expectationTestServerSuccessRequestResponse];

  // 1.5. Expect batch to be removed.
  self.testStorage.removeBatchWithIDExpectation =
      [self expectationWithDescription:@"removeBatchWithIDExpectation"];

  // 2. Create uploader and start upload.
  GDTCCTUploader *uploader = [[GDTCCTUploader alloc] init];
  uploader.testServerURL = [self.testServer.serverURL URLByAppendingPathComponent:@"logBatch"];

  // 2.1. Trigger upload 1st time.
  [self.generator generateEvent:GDTCOREventQoSFast];
  [uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 2.2. Trigger upload 2nd time.
  [self.generator generateEvent:GDTCOREventQoSFast];
  [uploader uploadTarget:kGDTCORTargetTest withConditions:GDTCORUploadConditionWifiData];

  // 3. Wait for operations to complete in the specified order.
  [self waitForExpectations:@[
    self.testStorage.batchIDsForTargetExpectation, self.testStorage.eventsInBatchWithIDExpectation,
    self.testStorage.batchWithEventSelectorExpectation, responseSentExpectation,
    self.testStorage.removeBatchWithIDExpectation
  ]
                    timeout:50
               enforceOrder:YES];

  // 4. Wait for upload operation to finish.
  XCTestExpectation *uploadFinishedExpectation =
      [self expectationWithDescription:@"uploadFinishedExpectation"];
  dispatch_sync(uploader.uploaderQueue, ^{
    [uploadFinishedExpectation fulfill];
    XCTAssertNil(uploader.currentTask);
  });
  [self waitForExpectations:@[ uploadFinishedExpectation ] timeout:0.5];
}

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

@end

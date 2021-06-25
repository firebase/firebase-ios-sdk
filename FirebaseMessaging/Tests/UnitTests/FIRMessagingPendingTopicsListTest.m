/*
 * Copyright 2017 Google
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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingPendingTopicsList.h"
#import "FirebaseMessaging/Sources/FIRMessagingTopicsCommon.h"

@interface FIRMessagingPendingTopicsListTest : XCTestCase

/// Using this delegate lets us prevent any topic operations from start, making it easy to measure
/// our batches
@property(nonatomic, strong) MockPendingTopicsListDelegate *notReadyDelegate;
/// Using this delegate will always begin topic operations (which will never return by default).
/// Useful for overriding with block-methods to handle update requests
@property(nonatomic, strong) MockPendingTopicsListDelegate *alwaysReadyDelegate;

@end

@implementation FIRMessagingPendingTopicsListTest

- (void)setUp {
  [super setUp];
  self.notReadyDelegate = [[MockPendingTopicsListDelegate alloc] init];
  self.notReadyDelegate.isReady = NO;

  self.alwaysReadyDelegate = [[MockPendingTopicsListDelegate alloc] init];
  self.alwaysReadyDelegate.isReady = YES;
}

- (void)tearDown {
  self.notReadyDelegate = nil;
  self.alwaysReadyDelegate = nil;
  [super tearDown];
}

- (void)testAddSingleTopic {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.notReadyDelegate;

  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  XCTAssertEqual(pendingTopics.numberOfBatches, 1);
}

- (void)testAddSameTopicAndActionMultipleTimes {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.notReadyDelegate;

  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  XCTAssertEqual(pendingTopics.numberOfBatches, 1);
}

- (void)testAddMultiplePendingTopicsWithSameAction {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.notReadyDelegate;

  for (NSInteger i = 0; i < 10; i++) {
    NSString *topic = [NSString stringWithFormat:@"/topics/%ld", (long)i];
    [pendingTopics addOperationForTopic:topic
                             withAction:FIRMessagingTopicActionSubscribe
                             completion:nil];
  }
  XCTAssertEqual(pendingTopics.numberOfBatches, 1);
}

- (void)testAddTopicsWithDifferentActions {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.notReadyDelegate;

  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/1"
                           withAction:FIRMessagingTopicActionUnsubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/2"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  XCTAssertEqual(pendingTopics.numberOfBatches, 3);
}

- (void)testBatchSizeReductionAfterSuccessfulTopicUpdate {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.alwaysReadyDelegate;

  XCTestExpectation *batchSizeReductionExpectation =
      [self expectationWithDescription:@"Batch size was reduced after topic suscription"];

  __weak id weakSelf = self;
  self.alwaysReadyDelegate.subscriptionHandler =
      ^(NSString *topic, FIRMessagingTopicAction action,
        FIRMessagingTopicOperationCompletion completion) {
        // Simulate that the handler is generally called asynchronously
        dispatch_async(dispatch_get_main_queue(), ^{
          if (action == FIRMessagingTopicActionUnsubscribe) {
            __unused id self = weakSelf;  // In Xcode 11, XCTAssertEqual references self.
            XCTAssertEqual(pendingTopics.numberOfBatches, 1);
            [batchSizeReductionExpectation fulfill];
          }
          completion(nil);
        });
      };

  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/1"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/2"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/1"
                           withAction:FIRMessagingTopicActionUnsubscribe
                           completion:nil];

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testCompletionOfTopicUpdatesInSameThread {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.alwaysReadyDelegate;

  XCTestExpectation *allOperationsSucceededed =
      [self expectationWithDescription:@"All queued operations succeeded"];

  self.alwaysReadyDelegate.subscriptionHandler =
      ^(NSString *topic, FIRMessagingTopicAction action,
        FIRMessagingTopicOperationCompletion completion) {
        // Typically, our callbacks happen asynchronously, but to ensure resilience,
        // call back the operation on the same thread it was called in.
        completion(nil);
      };

  self.alwaysReadyDelegate.updateHandler = ^{
    if (pendingTopics.numberOfBatches == 0) {
      [allOperationsSucceededed fulfill];
    }
  };

  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/1"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  [pendingTopics addOperationForTopic:@"/topics/2"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAddingTopicToCurrentBatchWhileCurrentBatchTopicsInFlight {
  FIRMessagingPendingTopicsList *pendingTopics = [[FIRMessagingPendingTopicsList alloc] init];
  pendingTopics.delegate = self.alwaysReadyDelegate;

  NSString *stragglerTopic = @"/topics/straggler";
  XCTestExpectation *stragglerTopicWasAddedToInFlightOperations =
      [self expectationWithDescription:@"The topic was added to in-flight operations"];

  self.alwaysReadyDelegate.subscriptionHandler =
      ^(NSString *topic, FIRMessagingTopicAction action,
        FIRMessagingTopicOperationCompletion completion) {
        if ([topic isEqualToString:stragglerTopic]) {
          [stragglerTopicWasAddedToInFlightOperations fulfill];
        }
        // Add a 0.5 second delay to the completion, to give time to add a straggler before the
        // batch is completed
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                         completion(nil);
                       });
      };

  // This is a normal topic, which should start fairly soon, but take a while to complete
  [pendingTopics addOperationForTopic:@"/topics/0"
                           withAction:FIRMessagingTopicActionSubscribe
                           completion:nil];
  // While waiting for the first topic to complete, we add another topic after a slight delay
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [pendingTopics addOperationForTopic:stragglerTopic
                                            withAction:FIRMessagingTopicActionSubscribe
                                            completion:nil];
                 });

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end

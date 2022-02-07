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

#import <OCMock/OCMock.h>

#import <GoogleUtilities/GULUserDefaults.h>
#import "FirebaseCore/Internal/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingPubSub.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"
#import "FirebaseMessaging/Tests/UnitTests/XCTestCase+FIRMessagingRmqManagerTests.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kFIRMessagingDefaultsTestDomain = @"com.messaging.tests";
static NSString *const kFakeSenderID = @"123456789123";

@interface FIRMessaging (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, strong) FIRMessagingTokenManager *tokenManager;

/// Surface internal initializer to avoid singleton usage during tests.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics
                 withUserDefaults:(GULUserDefaults *)defaults;
#pragma clang diagnostic pop
/// Kicks off required calls for some messaging tests.
- (void)start;
- (void)setupRmqManager;

@end

@interface FIRMessagingRmqManager (ExposedForTest)

- (void)removeDatabase;

@end

@implementation MockPendingTopicsListDelegate

- (BOOL)pendingTopicsListCanRequestTopicUpdates:(FIRMessagingPendingTopicsList *)list {
  return self.isReady;
}

- (void)pendingTopicsList:(FIRMessagingPendingTopicsList *)list
    requestedUpdateForTopic:(NSString *)topic
                     action:(FIRMessagingTopicAction)action
                 completion:(FIRMessagingTopicOperationCompletion)completion {
  if (self.subscriptionHandler) {
    self.subscriptionHandler(topic, action, completion);
  }
}

- (void)pendingTopicsListDidUpdate:(FIRMessagingPendingTopicsList *)list {
  if (self.updateHandler) {
    self.updateHandler();
  }
}

@end

@implementation FIRMessagingTestUtilities {
  id _mockMessagingClass;
}

- (instancetype)initWithUserDefaults:(GULUserDefaults *)userDefaults
                      withRMQManager:(BOOL)withRMQManager {
  self = [super init];
  if (self) {
    // `+[FIRInstallations installations]` supposed to be used on `-[FIRInstanceID start]` to get
    // `FIRInstallations` default instance. Need to stub it before.
    _mockInstallations = OCMClassMock([FIRInstallations class]);
    OCMStub([self.mockInstallations installations]).andReturn(self.mockInstallations);

    // Create the messaging instance and call `start`.
    _messaging = [[FIRMessaging alloc] initWithAnalytics:nil withUserDefaults:userDefaults];
    if (withRMQManager) {
      [_messaging start];
    }
    _mockMessaging = OCMPartialMock(_messaging);
    if (!withRMQManager) {
      OCMStub([_mockMessaging setupRmqManager]).andDo(nil);
      [(FIRMessaging *)_mockMessaging start];
    }
    _mockPubsub = OCMPartialMock(_messaging.pubsub);
    _mockTokenManager = OCMPartialMock(_messaging.tokenManager);
    _mockMessagingClass = OCMClassMock([FIRMessaging class]);
    OCMStub([_mockMessagingClass messaging]).andReturn(_mockMessaging);
    OCMStub([_mockTokenManager fcmSenderID]).andReturn(kFakeSenderID);
  }
  return self;
}

- (void)cleanupAfterTest:(XCTestCase *)testCase {
  [_messaging.rmq2Manager removeDatabase];
  [testCase waitForDrainDatabaseQueueForRmqManager:_messaging.rmq2Manager];
  [_messaging.messagingUserDefaults removePersistentDomainForName:kFIRMessagingDefaultsTestDomain];
  [_mockPubsub stopMocking];
  [_mockMessaging stopMocking];
  [_mockMessagingClass stopMocking];
  [_mockTokenManager stopMocking];
  [_mockInstallations stopMocking];
}

@end

NS_ASSUME_NONNULL_END

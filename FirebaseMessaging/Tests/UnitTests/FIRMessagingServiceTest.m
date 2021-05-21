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

#import <GoogleUtilities/GULUserDefaults.h>
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingPubSub.h"
#import "FirebaseMessaging/Sources/FIRMessagingTopicsCommon.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

static NSString *const kFakeToken =
    @"fE1e1PZJFSQ:APA91bFAOjp1ahBWn9rTlbjArwBEm_"
    @"yUTTzK6dhIvLqzqqCSabaa4TQVM0pGTmF6r7tmMHPe6VYiGMHuCwJFgj5v97xl78sUNMLwuPPhoci8z_"
    @"QGlCrTbxCFGzEUfvA3fGpGgIVQU2W6";
static NSString *const kFakeID = @"fE1e1PZJFSQ";
static NSString *const kFIRMessagingTestsServiceSuiteName = @"com.messaging.test_serviceTest";

@interface FIRMessaging ()
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;

@end

@interface FIRMessagingPubSub (ExposedForTest)

- (void)updateSubscriptionWithToken:(NSString *)token
                              topic:(NSString *)topic
                            options:(NSDictionary *)options
                       shouldDelete:(BOOL)shouldDelete
                            handler:(FIRMessagingTopicOperationCompletion)handler;

@end

@interface FIRMessagingServiceTest : XCTestCase {
  FIRMessaging *_messaging;
  id _mockMessaging;
  id _mockPubSub;
  id _mockTokenManager;
  id _mockInstallations;
  FIRMessagingTestUtilities *_testUtil;
}

@end

@implementation FIRMessagingServiceTest

- (void)setUp {
  [super setUp];
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsServiceSuiteName];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  _mockMessaging = _testUtil.mockMessaging;
  _messaging = _testUtil.messaging;
  _mockTokenManager = _testUtil.mockTokenManager;
  _mockInstallations = _testUtil.mockInstallations;
  OCMStub([_mockTokenManager defaultFCMToken]).andReturn(kFakeToken);
  _mockPubSub = _testUtil.mockPubsub;
}

- (void)tearDown {
  [_testUtil cleanupAfterTest:self];
  _messaging = nil;
  [_mockPubSub stopMocking];
  [[[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsServiceSuiteName]
      removePersistentDomainForName:kFIRMessagingTestsServiceSuiteName];
  [super tearDown];
}

- (void)testSubscribe {
  XCTestExpectation *subscribeExpectation =
      [self expectationWithDescription:@"Should call subscribe on Pubsub"];
  NSString *token = kFakeToken;
  NSString *topic = @"/topics/some-random-topic";

  [[[_mockPubSub stub] andDo:^(NSInvocation *invocation) {
    [subscribeExpectation fulfill];
  }] updateSubscriptionWithToken:token
                           topic:topic
                         options:OCMOCK_ANY
                    shouldDelete:NO
                         handler:OCMOCK_ANY];

  [_mockPubSub subscribeWithToken:token
                            topic:topic
                          options:nil
                          handler:^(NSError *error){
                              // not a nil block
                          }];

  // should call updateSubscription
  [self waitForExpectationsWithTimeout:0.1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                                 [self->_mockPubSub verify];
                               }];
}

- (void)testUnsubscribe {
  XCTestExpectation *subscribeExpectation =
      [self expectationWithDescription:@"Should call unsubscribe on Pubsub"];

  NSString *token = kFakeToken;
  NSString *topic = @"/topics/some-random-topic";

  [[[_mockPubSub stub] andDo:^(NSInvocation *invocation) {
    [subscribeExpectation fulfill];
  }] updateSubscriptionWithToken:[OCMArg isEqual:token]
                           topic:[OCMArg isEqual:topic]
                         options:[OCMArg checkWithBlock:^BOOL(id obj) {
                           if ([obj isKindOfClass:[NSDictionary class]]) {
                             return [(NSDictionary *)obj count] == 0;
                           }
                           return NO;
                         }]
                    shouldDelete:YES
                         handler:OCMOCK_ANY];

  [_mockPubSub unsubscribeWithToken:token
                              topic:topic
                            options:nil
                            handler:^(NSError *error){
                            }];

  // should call updateSubscription
  [self waitForExpectationsWithTimeout:0.1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                                 [self->_mockPubSub verify];
                               }];
}

- (void)testSubscribeWithNoTopicPrefix {
  [self mockTokenRequestSuccess];
  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  OCMExpect([_mockPubSub subscribeToTopic:[OCMArg isEqual:topicNameWithPrefix]
                                  handler:[OCMArg any]]);
  [_messaging subscribeToTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testSubscribeWithTopicPrefix {
  [self mockTokenRequestSuccess];

  NSString *topicName = @"/topics/topicWithoutPrefix";
  OCMExpect([_mockPubSub subscribeToTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [_messaging subscribeToTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testUnsubscribeWithNoTopicPrefix {
  [self mockTokenRequestSuccess];

  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  OCMExpect([_mockPubSub unsubscribeFromTopic:[OCMArg isEqual:topicNameWithPrefix]
                                      handler:[OCMArg any]]);
  [_messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testUnsubscribeWithTopicPrefix {
  [self mockTokenRequestSuccess];

  NSString *topicName = @"/topics/topicWithPrefix";
  OCMExpect([_mockPubSub unsubscribeFromTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [_messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testSubscriptionCompletionHandlerWithSuccess {
  [self mockTokenRequestSuccess];

  OCMStub([_mockPubSub subscribeToTopic:[OCMArg any]
                                handler:([OCMArg invokeBlockWithArgs:[NSNull null], nil])]);
  XCTestExpectation *subscriptionCompletionExpectation =
      [self expectationWithDescription:@"Subscription is complete"];
  [_messaging subscribeToTopic:@"news"
                    completion:^(NSError *error) {
                      XCTAssertNil(error);
                      [subscriptionCompletionExpectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:0.2
                               handler:^(NSError *_Nullable error){
                               }];
}

- (void)testUnsubscribeCompletionHandlerWithSuccess {
  [self mockTokenRequestSuccess];

  OCMStub([_mockPubSub unsubscribeFromTopic:[OCMArg any]
                                    handler:([OCMArg invokeBlockWithArgs:[NSNull null], nil])]);
  XCTestExpectation *unsubscriptionCompletionExpectation =
      [self expectationWithDescription:@"Unsubscription is complete"];
  [_messaging unsubscribeFromTopic:@"news"
                        completion:^(NSError *_Nullable error) {
                          XCTAssertNil(error);
                          [unsubscriptionCompletionExpectation fulfill];
                        }];
  [self waitForExpectationsWithTimeout:0.2
                               handler:^(NSError *_Nullable error){
                               }];
}

- (void)testSubscriptionCompletionHandlerWithInvalidTopicName {
  [self mockTokenRequestSuccess];

  XCTestExpectation *subscriptionCompletionExpectation =
      [self expectationWithDescription:@"Subscription is complete"];
  [_messaging subscribeToTopic:@"!@#$%^&*()"
                    completion:^(NSError *_Nullable error) {
                      XCTAssertNotNil(error);
                      XCTAssertEqual(error.code, FIRMessagingErrorInvalidTopicName);
                      [subscriptionCompletionExpectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:0.2
                               handler:^(NSError *_Nullable error){
                               }];
}

- (void)testUnsubscribeCompletionHandlerWithInvalidTopicName {
  [self mockTokenRequestSuccess];

  XCTestExpectation *unsubscriptionCompletionExpectation =
      [self expectationWithDescription:@"Unsubscription is complete"];
  [_messaging unsubscribeFromTopic:@"!@#$%^&*()"
                        completion:^(NSError *error) {
                          XCTAssertNotNil(error);
                          XCTAssertEqual(error.code, FIRMessagingErrorInvalidTopicName);
                          [unsubscriptionCompletionExpectation fulfill];
                        }];
  [self waitForExpectationsWithTimeout:0.2
                               handler:^(NSError *_Nullable error){
                               }];
}

- (void)testSubscribeFailedWithInvalidToken {
  // Mock get token is failed with FIRMessagingErrorUnknown error.
  XCTestExpectation *subscriptionCompletionExpectation =
      [self expectationWithDescription:@"Subscription is complete"];
  NSString *failureReason = @"Invalid token.";
  OCMStub([_mockMessaging
      retrieveFCMTokenForSenderID:[OCMArg any]
                       completion:([OCMArg
                                      invokeBlockWithArgs:
                                          [NSNull null],
                                          [NSError
                                              messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                                       failureReason:failureReason],
                                          nil])]);
  [_messaging subscribeToTopic:@"Apple"
                    completion:^(NSError *_Nullable error) {
                      XCTAssertNotNil(error);
                      XCTAssertEqual(error.code, kFIRMessagingErrorCodeUnknown);
                      XCTAssertEqualObjects(failureReason, error.localizedFailureReason);

                      [subscriptionCompletionExpectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:0.2 handler:nil];
}

- (void)testUnsubscribeFailedWithInvalidToken {
  NSString *failureReason = @"Invalid token.";
  OCMStub([_mockMessaging
      retrieveFCMTokenForSenderID:[OCMArg any]
                       completion:([OCMArg
                                      invokeBlockWithArgs:
                                          [NSNull null],
                                          [NSError
                                              messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                                       failureReason:failureReason],
                                          nil])]);
  XCTestExpectation *unsubscriptionCompletionExpectation =
      [self expectationWithDescription:@"Unsubscription is complete"];

  [_messaging unsubscribeFromTopic:@"news"
                        completion:^(NSError *_Nullable error) {
                          XCTAssertNotNil(error);
                          XCTAssertEqual(error.code, kFIRMessagingErrorCodeUnknown);
                          XCTAssertEqualObjects(failureReason, error.localizedFailureReason);
                          [unsubscriptionCompletionExpectation fulfill];
                        }];
  [self waitForExpectationsWithTimeout:0.2 handler:nil];
}

- (void)mockTokenRequestSuccess {
  OCMStub([_mockInstallations
      installationIDWithCompletion:([OCMArg invokeBlockWithArgs:kFakeID, [NSNull null], nil])]);
  OCMStub([_mockMessaging
      retrieveFCMTokenForSenderID:[OCMArg any]
                       completion:([OCMArg invokeBlockWithArgs:kFakeToken, [NSNull null], nil])]);
}

@end

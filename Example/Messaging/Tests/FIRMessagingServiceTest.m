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

#import <FirebaseInstanceID/FirebaseInstanceID.h>

#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"
#import <FirebaseMessaging/FIRMessaging.h>
#import "Firebase/Messaging/FIRMessagingClient.h"
#import "Firebase/Messaging/FIRMessagingPubSub.h"
#import "Firebase/Messaging/FIRMessagingTopicsCommon.h"
#import "Firebase/Messaging/NSError+FIRMessaging.h"

static NSString *const kFakeToken =
    @"fE1e1PZJFSQ:APA91bFAOjp1ahBWn9rTlbjArwBEm_"
    @"yUTTzK6dhIvLqzqqCSabaa4TQVM0pGTmF6r7tmMHPe6VYiGMHuCwJFgj5v97xl78sUNMLwuPPhoci8z_"
    @"QGlCrTbxCFGzEUfvA3fGpGgIVQU2W6";
static NSString *const kFakeID = @"fE1e1PZJFSQ";
static NSString *const kFIRMessagingSDKClassString = @"FIRMessaging";
static NSString *const kFIRMessagingSDKVersionSelectorString = @"FIRMessagingSDKVersion";
static NSString *const kFIRMessagingSDKLocaleSelectorString = @"FIRMessagingSDKCurrentLocale";
static NSString *const kFIRMessagingTestsServiceSuiteName = @"com.messaging.test_serviceTest";

@interface FIRMessaging () <FIRMessagingClientDelegate>
@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;
@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;

@end

@interface FIRMessagingPubSub ()

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;

@end

@interface FIRInstanceIDResult (ExposedForTest)
@property(nonatomic, readwrite, copy) NSString *instanceID;
@property(nonatomic, readwrite, copy) NSString *token;
@end

@interface FIRMessagingServiceTest : XCTestCase {
  FIRMessaging *_messaging;
  FIRInstanceIDResult *_result;
  id _mockInstanceID;
  id _mockPubSub;
}

@end

@implementation FIRMessagingServiceTest

- (void)setUp {
  [super setUp];
  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsServiceSuiteName];
  _messaging = [FIRMessagingTestUtilities messagingForTestsWithUserDefaults:defaults];
  _messaging.defaultFcmToken = kFakeToken;
  _mockPubSub = OCMPartialMock(_messaging.pubsub);
  [_mockPubSub setClient:nil];

  _mockInstanceID = OCMPartialMock(_messaging.instanceID);
  _result = [[FIRInstanceIDResult alloc] init];
  _result.token = kFakeToken;
  _result.instanceID = kFakeID;
}

- (void)tearDown {
  [_mockInstanceID stopMocking];
  [_mockPubSub stopMocking];
  [_messaging.messagingUserDefaults removePersistentDomainForName:kFIRMessagingTestsServiceSuiteName];
  _messaging = nil;
  [super tearDown];
}

- (void)testSubscribe {
  id mockClient = OCMClassMock([FIRMessagingClient class]);
  [_messaging setClient:mockClient];
  [_mockPubSub setClient:mockClient];

  XCTestExpectation *subscribeExpectation =
      [self expectationWithDescription:@"Should call subscribe on FIRMessagingClient"];
  NSString *token = kFakeToken;
  NSString *topic = @"/topics/some-random-topic";

  [[[mockClient stub]
    andDo:^(NSInvocation *invocation) {
      [subscribeExpectation fulfill];
    }]
      updateSubscriptionWithToken:token
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
                                 [mockClient verify];
                               }];
}

- (void)testUnsubscribe {
  id mockClient = OCMClassMock([FIRMessagingClient class]);
  [_messaging setClient:mockClient];
  [_mockPubSub setClient:mockClient];

  XCTestExpectation *subscribeExpectation =
      [self expectationWithDescription:@"Should call unsubscribe on FIRMessagingClient"];

  NSString *token = kFakeToken;
  NSString *topic = @"/topics/some-random-topic";

  [[[mockClient stub] andDo:^(NSInvocation *invocation) {
    [subscribeExpectation fulfill];
  }]
      updateSubscriptionWithToken:[OCMArg isEqual:token]
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
                                 [mockClient verify];
                               }];
}

/**
 *  Test using PubSub without explicitly starting FIRMessagingService.
 */
- (void)testSubscribeWithoutStart {
  [_mockPubSub
      subscribeWithToken:kFakeToken
                   topic:@"/topics/hello-world"
                 options:nil
                 handler:^(NSError *error) {
                   XCTAssertNotNil(error);
                   XCTAssertEqual(kFIRMessagingErrorCodePubSubFIRMessagingNotSetup, error.code);
                 }];
}

- (void)testSubscribeWithNoTopicPrefix {
  OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  OCMExpect(
      [_mockPubSub subscribeToTopic:[OCMArg isEqual:topicNameWithPrefix] handler:[OCMArg any]]);
  [_messaging subscribeToTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testSubscribeWithTopicPrefix {
   OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
  NSString *topicName = @"/topics/topicWithoutPrefix";
  OCMExpect([_mockPubSub subscribeToTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [_messaging subscribeToTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testUnsubscribeWithNoTopicPrefix {
  OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  OCMExpect(
      [_mockPubSub unsubscribeFromTopic:[OCMArg isEqual:topicNameWithPrefix] handler:[OCMArg any]]);
  [_messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testUnsubscribeWithTopicPrefix {
  OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
  NSString *topicName = @"/topics/topicWithPrefix";
  OCMExpect([_mockPubSub unsubscribeFromTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [_messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testSubscriptionCompletionHandlerWithSuccess {
   OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
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
  OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
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
   OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
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
   OCMStub([_mockInstanceID
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:_result, [NSNull null], nil])]);
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

- (void)testFIRMessagingSDKVersionInFIRMessagingService {
  Class versionClass = NSClassFromString(kFIRMessagingSDKClassString);
  SEL versionSelector = NSSelectorFromString(kFIRMessagingSDKVersionSelectorString);
  if ([versionClass respondsToSelector:versionSelector]) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id versionString = [versionClass performSelector:versionSelector];
#pragma clang diagnostic pop

    XCTAssertTrue([versionString isKindOfClass:[NSString class]]);
  } else {
    XCTFail("%@ does not respond to selector %@",
            kFIRMessagingSDKClassString, kFIRMessagingSDKVersionSelectorString);
  }
}

- (void)testFIRMessagingSDKLocaleInFIRMessagingService {
  Class klass = NSClassFromString(kFIRMessagingSDKClassString);
  SEL localeSelector = NSSelectorFromString(kFIRMessagingSDKLocaleSelectorString);
  if ([klass respondsToSelector:localeSelector]) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id locale = [klass performSelector:localeSelector];
#pragma clang diagnostic pop

    XCTAssertTrue([locale isKindOfClass:[NSString class]]);
    XCTAssertNotNil(locale);
  } else {
    XCTFail("%@ does not respond to selector %@",
            kFIRMessagingSDKClassString, kFIRMessagingSDKLocaleSelectorString);
  }
}


- (void)testSubscribeFailedWithInvalidToken {
  // Mock get token is failed with FIRMessagingErrorUnknown error.
  XCTestExpectation *subscriptionCompletionExpectation =
      [self expectationWithDescription:@"Subscription is complete"];
  OCMStub([_mockInstanceID
      instanceIDWithHandler:
          ([OCMArg
              invokeBlockWithArgs:[NSNull null],
                                  [NSError errorWithFCMErrorCode:kFIRMessagingErrorCodeUnknown],
                                  nil])]);
  [_messaging subscribeToTopic:@"Apple"
                    completion:^(NSError *_Nullable error) {
                      XCTAssertNotNil(error);
                      XCTAssertEqual(error.code, kFIRMessagingErrorCodeUnknown);
                      [subscriptionCompletionExpectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:0.2 handler:nil];
}

- (void)testUnsubscribeFailedWithInvalidToken {
  OCMStub([_mockInstanceID
      instanceIDWithHandler:
          ([OCMArg
              invokeBlockWithArgs:[NSNull null],
                                  [NSError errorWithFCMErrorCode:kFIRMessagingErrorCodeUnknown],
                                  nil])]);
  XCTestExpectation *unsubscriptionCompletionExpectation =
      [self expectationWithDescription:@"Unsubscription is complete"];

  [_messaging unsubscribeFromTopic:@"news"
                        completion:^(NSError *_Nullable error) {
                          XCTAssertNotNil(error);
                          XCTAssertEqual(error.code, kFIRMessagingErrorCodeUnknown);
                          [unsubscriptionCompletionExpectation fulfill];
                        }];
  [self waitForExpectationsWithTimeout:0.2 handler:nil];
}
@end

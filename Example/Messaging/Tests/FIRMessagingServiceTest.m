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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FIRMessaging.h"
#import "FIRMessagingClient.h"
#import "FIRMessagingPubSub.h"
#import "FIRMessagingTopicsCommon.h"
#import "InternalHeaders/FIRMessagingInternalUtilities.h"
#import "NSError+FIRMessaging.h"

static NSString *const kFakeToken =
    @"fE1e1PZJFSQ:APA91bFAOjp1ahBWn9rTlbjArwBEm_"
    @"yUTTzK6dhIvLqzqqCSabaa4TQVM0pGTmF6r7tmMHPe6VYiGMHuCwJFgj5v97xl78sUNMLwuPPhoci8z_"
    @"QGlCrTbxCFGzEUfvA3fGpGgIVQU2W6";

@interface FIRMessaging () <FIRMessagingClientDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;

@end

@interface FIRMessagingPubSub ()

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;

@end

@interface FIRMessagingServiceTest : XCTestCase {
  FIRMessaging *_messaging;
  id _mockPubSub;
}

@end

@implementation FIRMessagingServiceTest

- (void)setUp {
  _messaging = [FIRMessaging messaging];
  _messaging.defaultFcmToken = kFakeToken;
  _mockPubSub = OCMPartialMock(_messaging.pubsub);
  [super setUp];
}

- (void)tearDown {
  [_mockPubSub stopMocking];
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
                   XCTAssertNil(error);
                   XCTAssertEqual(kFIRMessagingErrorCodePubSubFIRMessagingNotSetup, error.code);
                 }];
}

// TODO(chliangGoogle) Investigate why invalid token can't throw assertion but the rest can under
// release build.
- (void)testSubscribeWithInvalidTopic {

  XCTestExpectation *exceptionExpectation =
  [self expectationWithDescription:@"Should throw exception for invalid token"];
  @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [_mockPubSub subscribeWithToken:kFakeToken
                              topic:nil
                            options:nil
                            handler:^(NSError *error) {
                              XCTFail(@"Should not invoke the handler");
                            }];
#pragma clang diagnostic pop
  }
  @catch (NSException *exception) {
    [exceptionExpectation fulfill];
  }
  @finally {
    [self waitForExpectationsWithTimeout:0.1 handler:^(NSError *error) {
      XCTAssertNil(error);
    }];
  }
}

- (void)testUnsubscribeWithInvalidTopic {
  XCTestExpectation *exceptionExpectation =
      [self expectationWithDescription:@"Should throw exception for invalid token"];
  @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [_mockPubSub unsubscribeWithToken:kFakeToken
                                topic:nil
                              options:nil
                              handler:^(NSError *error) {
                                XCTFail(@"Should not invoke the handler");
                              }];
#pragma clang diagnostic pop
  }
  @catch (NSException *exception) {
    [exceptionExpectation fulfill];
  }
  @finally {
    [self waitForExpectationsWithTimeout:0.1 handler:^(NSError *error) {
      XCTAssertNil(error);
    }];
  }
}

- (void)testSubscribeWithNoTopicPrefix {

  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  OCMExpect(
      [_mockPubSub subscribeToTopic:[OCMArg isEqual:topicNameWithPrefix] handler:[OCMArg any]]);
  [_messaging subscribeToTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testSubscribeWithTopicPrefix {
  NSString *topicName = @"/topics/topicWithoutPrefix";
  OCMExpect([_mockPubSub subscribeToTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [_messaging subscribeToTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testUnsubscribeWithNoTopicPrefix {
  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  OCMExpect(
      [_mockPubSub unsubscribeFromTopic:[OCMArg isEqual:topicNameWithPrefix] handler:[OCMArg any]]);
  [_messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testUnsubscribeWithTopicPrefix {
  NSString *topicName = @"/topics/topicWithPrefix";
  OCMExpect([_mockPubSub unsubscribeFromTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [_messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(_mockPubSub);
}

- (void)testSubscriptionCompletionHandlerWithSuccess {
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

@end

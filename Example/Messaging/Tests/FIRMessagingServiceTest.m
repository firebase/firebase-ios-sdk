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

@interface FIRMessaging () <FIRMessagingClientDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;

@end

@interface FIRMessagingPubSub ()

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;

@end


@interface FIRMessagingServiceTest : XCTestCase

@end

@implementation FIRMessagingServiceTest

- (void)testSubscribe {
  id mockClient = OCMClassMock([FIRMessagingClient class]);
  FIRMessaging *service = [FIRMessaging messaging];
  [service setClient:mockClient];
  [service.pubsub setClient:mockClient];

  XCTestExpectation *subscribeExpectation =
      [self expectationWithDescription:@"Should call subscribe on FIRMessagingClient"];
  NSString *token = @"abcdefghijklmn";
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

  [service.pubsub subscribeWithToken:token
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
  FIRMessaging *messaging = [FIRMessaging messaging];
  [messaging setClient:mockClient];
  [messaging.pubsub setClient:mockClient];

  XCTestExpectation *subscribeExpectation =
      [self expectationWithDescription:@"Should call unsubscribe on FIRMessagingClient"];

  NSString *token = @"abcdefghijklmn";
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

  [messaging.pubsub unsubscribeWithToken:token
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
  [[[FIRMessaging messaging] pubsub]
      subscribeWithToken:@"abcdef1234"
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
  FIRMessaging *messaging = [FIRMessaging messaging];

  XCTestExpectation *exceptionExpectation =
  [self expectationWithDescription:@"Should throw exception for invalid token"];
  @try {
    [messaging.pubsub subscribeWithToken:@"abcdef1234"
                                   topic:nil
                                 options:nil
                                 handler:^(NSError *error) {
                                   XCTFail(@"Should not invoke the handler");
                                 }];
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
  FIRMessaging *messaging = [FIRMessaging messaging];

  XCTestExpectation *exceptionExpectation =
      [self expectationWithDescription:@"Should throw exception for invalid token"];
  @try {
    [messaging.pubsub unsubscribeWithToken:@"abcdef1234"
                                     topic:nil
                                   options:nil
                                   handler:^(NSError *error) {
                                     XCTFail(@"Should not invoke the handler");
                                   }];
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
  FIRMessaging *messaging = [FIRMessaging messaging];
  FIRMessagingPubSub *pubSub = messaging.pubsub;
  id mockPubSub = OCMClassMock([FIRMessagingPubSub class]);

  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  messaging.pubsub = mockPubSub;
  messaging.defaultFcmToken = @"fake-default-token";
  OCMExpect([messaging.pubsub subscribeToTopic:[OCMArg isEqual:topicNameWithPrefix]
                                       handler:[OCMArg any]]);
  [messaging subscribeToTopic:topicName];
  OCMVerifyAll(mockPubSub);
  // Need to swap back since it's a singleton and hence will live beyond the scope of this test.
  messaging.pubsub = pubSub;
}

- (void)testSubscribeWithTopicPrefix {
  FIRMessaging *messaging = [FIRMessaging messaging];
  FIRMessagingPubSub *pubSub = messaging.pubsub;
  id mockPubSub = OCMClassMock([FIRMessagingPubSub class]);

  NSString *topicName = @"/topics/topicWithoutPrefix";
  messaging.pubsub = mockPubSub;
  messaging.defaultFcmToken = @"fake-default-token";
  OCMExpect([messaging.pubsub subscribeToTopic:[OCMArg isEqual:topicName] handler:[OCMArg any]]);
  [messaging subscribeToTopic:topicName];
  OCMVerifyAll(mockPubSub);
  // Need to swap back since it's a singleton and hence will live beyond the scope of this test.
  messaging.pubsub = pubSub;
}

- (void)testUnsubscribeWithNoTopicPrefix {
  FIRMessaging *messaging = [FIRMessaging messaging];
  FIRMessagingPubSub *pubSub = messaging.pubsub;
  id mockPubSub = OCMClassMock([FIRMessagingPubSub class]);

  NSString *topicName = @"topicWithoutPrefix";
  NSString *topicNameWithPrefix = [FIRMessagingPubSub addPrefixToTopic:topicName];
  messaging.pubsub = mockPubSub;
  messaging.defaultFcmToken = @"fake-default-token";
  OCMExpect([messaging.pubsub unsubscribeFromTopic:[OCMArg isEqual:topicNameWithPrefix]
                                           handler:[OCMArg any]]);
  [messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(mockPubSub);
  // Need to swap back since it's a singleton and hence will live beyond the scope of this test.
  messaging.pubsub = pubSub;
}

- (void)testUnsubscribeWithTopicPrefix {
  FIRMessaging *messaging = [FIRMessaging messaging];
  FIRMessagingPubSub *pubSub = messaging.pubsub;
  id mockPubSub = OCMClassMock([FIRMessagingPubSub class]);

  NSString *topicName = @"/topics/topicWithPrefix";
  messaging.pubsub = mockPubSub;
  messaging.defaultFcmToken = @"fake-default-token";
  OCMExpect([messaging.pubsub unsubscribeFromTopic:[OCMArg isEqual:topicName]
                                           handler:[OCMArg any]]);
  [messaging unsubscribeFromTopic:topicName];
  OCMVerifyAll(mockPubSub);
  // Need to swap back since it's a singleton and hence will live beyond the scope of this test.
  messaging.pubsub = pubSub;
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

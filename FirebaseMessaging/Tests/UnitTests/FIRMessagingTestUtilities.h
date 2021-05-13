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

#import <Foundation/Foundation.h>

#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"

#import "FirebaseMessaging/Sources/FIRMessagingPendingTopicsList.h"
#import "FirebaseMessaging/Sources/FIRMessagingTopicsCommon.h"

@class GULUserDefaults;
@class XCTestCase;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kFIRMessagingDefaultsTestDomain;

typedef void (^MockDelegateSubscriptionHandler)(NSString *topic,
                                                FIRMessagingTopicAction action,
                                                FIRMessagingTopicOperationCompletion completion);

/**
 * This object lets us provide a stub delegate where we can customize the behavior by providing
 * blocks. We need to use this instead of stubbing a OCMockProtocol because our delegate methods
 * take primitive values (e.g. action), which is not easy to use from OCMock
 * @see http://stackoverflow.com/a/6332023
 */
@interface MockPendingTopicsListDelegate : NSObject <FIRMessagingPendingTopicsListDelegate>

@property(nonatomic, assign) BOOL isReady;
@property(nonatomic, copy) MockDelegateSubscriptionHandler subscriptionHandler;
@property(nonatomic, copy) void (^updateHandler)(void);

@end

@interface FIRMessaging (TestUtilities)
// Surface the user defaults instance to clean up after tests.
@property(nonatomic, strong) NSUserDefaults *messagingUserDefaults;

@end

@interface FIRMessagingTestUtilities : NSObject

@property(nonatomic, strong) id mockPubsub;
@property(nonatomic, strong) id mockMessaging;
@property(nonatomic, strong) id mockInstallations;
@property(nonatomic, strong) id mockTokenManager;
@property(nonatomic, readonly, strong) FIRMessaging *messaging;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                      withRMQManager:(BOOL)withRMQManager;

- (void)cleanupAfterTest:(XCTestCase *)testCase;

@end

NS_ASSUME_NONNULL_END

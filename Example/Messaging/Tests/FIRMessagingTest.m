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

@import XCTest;

#import <OCMock/OCMock.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>

#import "FIRMessaging.h"
#import "FIRMessaging_Private.h"

extern NSString *const kFIRMessagingFCMTokenFetchAPNSOption;

@interface FIRMessaging ()

@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;
@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;
@property(nonatomic, readwrite, strong) NSUserDefaults *messagingUserDefaults;

- (instancetype)initWithInstanceID:(FIRInstanceID *)instanceID
                      userDefaults:(NSUserDefaults *)defaults;
// Direct Channel Methods
- (void)updateAutomaticClientConnection;
- (BOOL)shouldBeConnectedAutomatically;

@end

@interface FIRMessagingTest : XCTestCase

@property(nonatomic, readonly, strong) FIRMessaging *messaging;
@property(nonatomic, readwrite, strong) id mockMessaging;
@property(nonatomic, readwrite, strong) id mockInstanceID;

@end

@implementation FIRMessagingTest

- (void)setUp {
  [super setUp];
  _messaging = [[FIRMessaging alloc] initWithInstanceID:[FIRInstanceID instanceID]
                                           userDefaults:[NSUserDefaults standardUserDefaults]];
  _mockMessaging = OCMPartialMock(self.messaging);
  _mockInstanceID = OCMPartialMock(self.messaging.instanceID);
  self.messaging.instanceID = _mockInstanceID;
  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:[NSBundle mainBundle].bundleIdentifier];
}

- (void)tearDown {
  _messaging = nil;
  [_mockMessaging stopMocking];
  _mockMessaging = nil;
  [_mockInstanceID stopMocking];
  _mockInstanceID = nil;
  [super tearDown];
}

- (void)testAutoInitEnableFlag {
  // Should read from Info.plist
  XCTAssertFalse(_messaging.isAutoInitEnabled);

  // Now set the flag should overwrite Info.plist value.
  _messaging.autoInitEnabled = YES;
  XCTAssertTrue(_messaging.isAutoInitEnabled);
}

#pragma mark - Direct Channel Establishment Testing

// Should connect with valid token and application in foreground
- (void)testDoesAutomaticallyConnectIfTokenAvailableAndForegrounded {
  // Disable actually attempting a connection
  [[[_mockMessaging stub] andDo:^(NSInvocation *invocation) {
    // Doing nothing on purpose, when -updateAutomaticClientConnection is called
  }] updateAutomaticClientConnection];
  // Set direct channel to be established after disabling connection attempt
  self.messaging.shouldEstablishDirectChannel = YES;
  // Set a "valid" token (i.e. not nil or empty)
  self.messaging.defaultFcmToken = @"1234567";
  // Swizzle application state to return UIApplicationStateActive
  UIApplication *app = [UIApplication sharedApplication];
  id mockApp = OCMPartialMock(app);
  [[[mockApp stub] andReturnValue:@(UIApplicationStateActive)] applicationState];
  BOOL shouldBeConnected = [_mockMessaging shouldBeConnectedAutomatically];
  XCTAssertTrue(shouldBeConnected);
}

// Should not connect if application is active, but token is empty
- (void)testDoesNotAutomaticallyConnectIfTokenIsEmpty {
  // Disable actually attempting a connection
  [[[_mockMessaging stub] andDo:^(NSInvocation *invocation) {
    // Doing nothing on purpose, when -updateAutomaticClientConnection is called
  }] updateAutomaticClientConnection];
  // Set direct channel to be established after disabling connection attempt
  self.messaging.shouldEstablishDirectChannel = YES;
  // By default, there should be no fcmToken
  // Swizzle application state to return UIApplicationStateActive
  UIApplication *app = [UIApplication sharedApplication];
  id mockApp = OCMPartialMock(app);
  [[[mockApp stub] andReturnValue:@(UIApplicationStateActive)] applicationState];
  BOOL shouldBeConnected = [_mockMessaging shouldBeConnectedAutomatically];
  XCTAssertFalse(shouldBeConnected);
}

// Should not connect if token valid but application isn't active
- (void)testDoesNotAutomaticallyConnectIfApplicationNotActive {
  // Disable actually attempting a connection
  [[[_mockMessaging stub] andDo:^(NSInvocation *invocation) {
    // Doing nothing on purpose, when -updateAutomaticClientConnection is called
  }] updateAutomaticClientConnection];
  // Set direct channel to be established after disabling connection attempt
  self.messaging.shouldEstablishDirectChannel = YES;
  // Set a "valid" token (i.e. not nil or empty)
  self.messaging.defaultFcmToken = @"abcd1234";
  // Swizzle application state to return UIApplicationStateActive
  UIApplication *app = [UIApplication sharedApplication];
  id mockApp = OCMPartialMock(app);
  [[[mockApp stub] andReturnValue:@(UIApplicationStateBackground)] applicationState];
  BOOL shouldBeConnected = [_mockMessaging shouldBeConnectedAutomatically];
  XCTAssertFalse(shouldBeConnected);
}

#pragma mark - FCM Token Fetching and Deleting

#ifdef NEED_WORKAROUND_FOR_PRIVATE_OCMOCK_getArgumentAtIndexAsObject
- (void)testAPNSTokenIncludedInOptionsIfAvailableDuringTokenFetch {
  self.messaging.apnsTokenData =
      [@"PRETENDING_TO_BE_A_DEVICE_TOKEN" dataUsingEncoding:NSUTF8StringEncoding];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Included APNS Token data in options dict."];
  // Inspect the 'options' dictionary to tell whether our expectation was fulfilled
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation) {
    // Calling getArgument:atIndex: directly leads to an EXC_BAD_ACCESS; use OCMock's wrapper.
    NSDictionary *options = [invocation getArgumentAtIndexAsObject:4];
    if (options[@"apns_token"] != nil) {
      [expectation fulfill];
    }
  }] tokenWithAuthorizedEntity:OCMOCK_ANY scope:OCMOCK_ANY options:OCMOCK_ANY handler:OCMOCK_ANY];
  [self.messaging retrieveFCMTokenForSenderID:@"123456"
                                   completion:^(NSString * _Nullable FCMToken,
                                                NSError * _Nullable error) {}];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testAPNSTokenNotIncludedIfUnavailableDuringTokenFetch {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Included APNS Token data not included in options dict."];
  // Inspect the 'options' dictionary to tell whether our expectation was fulfilled
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation) {
    // Calling getArgument:atIndex: directly leads to an EXC_BAD_ACCESS; use OCMock's wrapper.
    NSDictionary *options = [invocation getArgumentAtIndexAsObject:4];
    if (options[@"apns_token"] == nil) {
      [expectation fulfill];
    }
  }] tokenWithAuthorizedEntity:OCMOCK_ANY scope:OCMOCK_ANY options:OCMOCK_ANY handler:OCMOCK_ANY];
  [self.messaging retrieveFCMTokenForSenderID:@"123456"
                                   completion:^(NSString * _Nullable FCMToken,
                                                NSError * _Nullable error) {}];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}
#endif

- (void)testReturnsErrorWhenFetchingTokenWithoutSenderID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Returned an error fetching token without Sender ID"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [self.messaging retrieveFCMTokenForSenderID:nil
                                  completion:
      ^(NSString * _Nullable FCMToken, NSError * _Nullable error) {
    if (error != nil) {
      [expectation fulfill];
    }
  }];
#pragma clang diagnostic pop
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testReturnsErrorWhenFetchingTokenWithEmptySenderID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Returned an error fetching token with empty Sender ID"];
  [self.messaging retrieveFCMTokenForSenderID:@""
                                  completion:
      ^(NSString * _Nullable FCMToken, NSError * _Nullable error) {
    if (error != nil) {
      [expectation fulfill];
    }
  }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testReturnsErrorWhenDeletingTokenWithoutSenderID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Returned an error deleting token without Sender ID"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [self.messaging deleteFCMTokenForSenderID:nil completion:^(NSError * _Nullable error) {
    if (error != nil) {
      [expectation fulfill];
    }
  }];
#pragma clang diagnostic pop
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testReturnsErrorWhenDeletingTokenWithEmptySenderID {
  XCTestExpectation *expectation =
  [self expectationWithDescription:@"Returned an error deleting token with empty Sender ID"];
  [self.messaging deleteFCMTokenForSenderID:@"" completion:^(NSError * _Nullable error) {
    if (error != nil) {
      [expectation fulfill];
    }
  }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

@end

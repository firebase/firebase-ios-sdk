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
#import "FirebaseCore/Internal/FirebaseCoreInternal.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

extern NSString *const kFIRMessagingFCMTokenFetchAPNSOption;

@interface FIRMessaging ()

@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;
@property(nonatomic, readwrite, strong) FIRMessagingTokenManager *tokenManager;

// Expose autoInitEnabled static method for IID.
+ (BOOL)isAutoInitEnabledWithUserDefaults:(NSUserDefaults *)userDefaults;

// Direct Channel Methods
- (void)updateAutomaticClientConnection;
- (BOOL)shouldBeConnectedAutomatically;

@end

@interface FIRMessagingTest : XCTestCase

@property(nonatomic, readonly, strong) FIRMessaging *messaging;
@property(nonatomic, readwrite, strong) id mockMessaging;
@property(nonatomic, readwrite, strong) id mockInstanceID;
@property(nonatomic, readwrite, strong) id mockFirebaseApp;
@property(nonatomic, readwrite, strong) id mockTokenManager;
@property(nonatomic, strong) FIRMessagingTestUtilities *testUtil;

@end

@implementation FIRMessagingTest

- (void)setUp {
  [super setUp];

  // Create the messaging instance with all the necessary dependencies.
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  _mockMessaging = _testUtil.mockMessaging;
  _messaging = _testUtil.messaging;
  _mockTokenManager = _testUtil.mockTokenManager;

  _mockFirebaseApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:[NSBundle mainBundle].bundleIdentifier];
}

- (void)tearDown {
  [_testUtil cleanupAfterTest:self];
  [_mockFirebaseApp stopMocking];
  _messaging = nil;
  [[[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain]
      removePersistentDomainForName:kFIRMessagingDefaultsTestDomain];
  [super tearDown];
}

- (void)testAutoInitEnableFlag {
  // Should read from Info.plist
  XCTAssertFalse(_messaging.isAutoInitEnabled);

  // Now set the flag should overwrite Info.plist value.
  _messaging.autoInitEnabled = YES;
  XCTAssertTrue(_messaging.isAutoInitEnabled);
}

- (void)testAutoInitEnableFlagOverrideGlobalTrue {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled]).andReturn(nil);
  XCTAssertTrue(self.messaging.isAutoInitEnabled);

  self.messaging.autoInitEnabled = NO;
  XCTAssertFalse(self.messaging.isAutoInitEnabled);
  [bundleMock stopMocking];
}

- (void)testAutoInitEnableFlagOverrideGlobalFalse {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled]).andReturn(nil);
  XCTAssertTrue(self.messaging.isAutoInitEnabled);

  self.messaging.autoInitEnabled = NO;
  XCTAssertFalse(self.messaging.isAutoInitEnabled);
  [bundleMock stopMocking];
}

- (void)testAutoInitEnableGlobalDefaultTrue {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled]).andReturn(nil);

  XCTAssertTrue(self.messaging.isAutoInitEnabled);
  [bundleMock stopMocking];
}

- (void)testAutoInitEnableGlobalDefaultFalse {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(NO);
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled]).andReturn(nil);

  XCTAssertFalse(self.messaging.isAutoInitEnabled);
  [bundleMock stopMocking];
}

- (void)testAutoInitEnabledMatchesStaticMethod {
  // Flag is set to YES in user defaults.
  NSUserDefaults *defaults = self.messaging.messagingUserDefaults;
  [defaults setObject:@YES forKey:kFIRMessagingUserDefaultsKeyAutoInitEnabled];

  XCTAssertTrue(self.messaging.isAutoInitEnabled);
  XCTAssertEqual(self.messaging.isAutoInitEnabled,
                 [FIRMessaging isAutoInitEnabledWithUserDefaults:defaults]);
}

- (void)testAutoInitDisabledMatchesStaticMethod {
  // Flag is set to NO in user defaults.
  NSUserDefaults *defaults = self.messaging.messagingUserDefaults;
  [defaults setObject:@NO forKey:kFIRMessagingUserDefaultsKeyAutoInitEnabled];

  XCTAssertFalse(self.messaging.isAutoInitEnabled);
  XCTAssertEqual(self.messaging.isAutoInitEnabled,
                 [FIRMessaging isAutoInitEnabledWithUserDefaults:defaults]);
}

#pragma mark - FCM Token Fetching and Deleting
// TODO(chliang) mock tokenManager
- (void)x_testAPNSTokenIncludedInOptionsIfAvailableDuringTokenFetch {
  self.messaging.apnsTokenData =
      [@"PRETENDING_TO_BE_A_DEVICE_TOKEN" dataUsingEncoding:NSUTF8StringEncoding];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Included APNS Token data in options dict."];
  // Inspect the 'options' dictionary to tell whether our expectation was fulfilled
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation) {
    __unsafe_unretained NSDictionary *options;
    [invocation getArgument:&options atIndex:4];
    if (options[@"apns_token"] != nil) {
      [expectation fulfill];
    }
  }] tokenWithAuthorizedEntity:OCMOCK_ANY scope:OCMOCK_ANY options:OCMOCK_ANY handler:OCMOCK_ANY];
  [self.messaging
      retrieveFCMTokenForSenderID:@"123456"
                       completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error){
                       }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)x_testAPNSTokenNotIncludedIfUnavailableDuringTokenFetch {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Included APNS Token data not included in options dict."];
  // Inspect the 'options' dictionary to tell whether our expectation was fulfilled
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation) {
    __unsafe_unretained NSDictionary *options;
    [invocation getArgument:&options atIndex:4];
    if (options[@"apns_token"] == nil) {
      [expectation fulfill];
    }
  }] tokenWithAuthorizedEntity:OCMOCK_ANY scope:OCMOCK_ANY options:OCMOCK_ANY handler:OCMOCK_ANY];
  [self.messaging
      retrieveFCMTokenForSenderID:@"123456"
                       completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error){
                       }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testReturnsErrorWhenFetchingTokenWithoutSenderID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Returned an error fetching token without Sender ID"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [self.messaging
      retrieveFCMTokenForSenderID:nil
                       completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error) {
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
  [self.messaging
      retrieveFCMTokenForSenderID:@""
                       completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error) {
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
  [self.messaging deleteFCMTokenForSenderID:nil
                                 completion:^(NSError *_Nullable error) {
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
  [self.messaging deleteFCMTokenForSenderID:@""
                                 completion:^(NSError *_Nullable error) {
                                   if (error != nil) {
                                     [expectation fulfill];
                                   }
                                 }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

@end

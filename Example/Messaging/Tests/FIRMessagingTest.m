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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <GoogleUtilities/GULUserDefaults.h>

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseMessaging/FIRMessaging.h>

#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"
#import "Firebase/Messaging/FIRMessaging_Private.h"


extern NSString *const kFIRMessagingFCMTokenFetchAPNSOption;

/// The NSUserDefaults domain for testing.
static NSString *const kFIRMessagingDefaultsTestDomain = @"com.messaging.tests";

@interface FIRMessaging ()

@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;
@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;

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
@property(nonatomic, strong) FIRMessagingTestUtilities *testUtil;

@end

@implementation FIRMessagingTest

- (void)setUp {
  [super setUp];

  _mockInstanceID = OCMClassMock([FIRInstanceID class]);

  // Create the messaging instance with all the necessary dependencies.
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults  withRMQManager:NO];
  _mockMessaging = _testUtil.mockMessaging;
  _messaging = _testUtil.messaging;

  _mockFirebaseApp = OCMClassMock([FIRApp class]);
   OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
  _mockInstanceID = _testUtil.mockInstanceID;
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

#pragma mark - Direct Channel Establishment Testing

#if TARGET_OS_IOS || TARGET_OS_TV
// Should connect with valid token and application in foreground
- (void)testDoesAutomaticallyConnectIfTokenAvailableAndForegrounded {
  // Disable actually attempting a connection
  [[[_mockMessaging stub] andDo:^(NSInvocation *invocation){
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
  BOOL shouldBeConnected = [_messaging shouldBeConnectedAutomatically];
  XCTAssertTrue(shouldBeConnected);
}

// Should not connect if application is active, but token is empty
- (void)testDoesNotAutomaticallyConnectIfTokenIsEmpty {
  // Disable actually attempting a connection
  [[[_mockMessaging stub] andDo:^(NSInvocation *invocation){
      // Doing nothing on purpose, when -updateAutomaticClientConnection is called
  }] updateAutomaticClientConnection];
  // Set direct channel to be established after disabling connection attempt
  self.messaging.shouldEstablishDirectChannel = YES;
  // By default, there should be no fcmToken
  // Swizzle application state to return UIApplicationStateActive
  UIApplication *app = [UIApplication sharedApplication];
  id mockApp = OCMPartialMock(app);
  [[[mockApp stub] andReturnValue:@(UIApplicationStateActive)] applicationState];
  BOOL shouldBeConnected = [_messaging shouldBeConnectedAutomatically];
  XCTAssertFalse(shouldBeConnected);
}

// Should not connect if token valid but application isn't active
- (void)testDoesNotAutomaticallyConnectIfApplicationNotActive {
  // Disable actually attempting a connection
  [[[_mockMessaging stub] andDo:^(NSInvocation *invocation){
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
#endif

#pragma mark - FCM Token Fetching and Deleting

- (void)testAPNSTokenIncludedInOptionsIfAvailableDuringTokenFetch {
  self.messaging.apnsTokenData =
      [@"PRETENDING_TO_BE_A_DEVICE_TOKEN" dataUsingEncoding:NSUTF8StringEncoding];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Included APNS Token data in options dict."];
  // Inspect the 'options' dictionary to tell whether our expectation was fulfilled
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation) {
    NSDictionary *options;
    [invocation getArgument:&options atIndex:4];
    if (options[@"apns_token"] != nil) {
      [expectation fulfill];
    }
  }] tokenWithAuthorizedEntity:OCMOCK_ANY scope:OCMOCK_ANY options:OCMOCK_ANY handler:OCMOCK_ANY];
  self.messaging.instanceID = self.mockInstanceID;
  [self.messaging
      retrieveFCMTokenForSenderID:@"123456"
                       completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error){
                       }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testAPNSTokenNotIncludedIfUnavailableDuringTokenFetch {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Included APNS Token data not included in options dict."];
  // Inspect the 'options' dictionary to tell whether our expectation was fulfilled
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation) {
    NSDictionary *options;
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

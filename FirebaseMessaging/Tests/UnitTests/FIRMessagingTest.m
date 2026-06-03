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
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingPubSub.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

@interface FIRInstallationsAuthTokenResult (Tests)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;
@end

@interface FIRMessagingTokenManager (ExposedForTest)
- (void)deleteAllTokensLocallyWithHandler:(void (^)(NSError *error))handler;
@end

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
- (void)configureMessagingWithOptions:(FIROptions *)options;

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

- (void)testReturnsErrorWhenFetchingTokenWithoutAPNSToken {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Returned an error fetching token without APNS Token"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [self.messaging
      retrieveFCMTokenForSenderID:@"12345"
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

- (void)setupV1RegistrationHttpCallWithMethod:(NSString *)httpMethod
                                 responseBody:(NSData *)responseBody
                       requestValidationBlock:(BOOL (^)(NSURLRequest *))requestValidationBlock {
  // Setup installation ID.
  id installationIDArg = [OCMArg invokeBlockWithArgs:@"fake-fid", [NSNull null], nil];
  OCMStub([(FIRInstallations *)self.testUtil.mockInstallations
      installationIDWithCompletion:installationIDArg]);

  // Setup FIS auth token.
  FIRInstallationsAuthTokenResult *mockAuthTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];
  id authTokenArg = [OCMArg invokeBlockWithArgs:mockAuthTokenResult, [NSNull null], nil];
  OCMStub(
      [(FIRInstallations *)self.testUtil.mockInstallations authTokenWithCompletion:authTokenArg]);

  id URLSessionMock = OCMClassMock([NSURLSession class]);
  OCMStub(ClassMethod([URLSessionMock sessionWithConfiguration:[OCMArg any]]))
      .andReturn(URLSessionMock);

  // Setup the HTTP response.
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];

  [FIRURLSessionOCMockStub stubURLSessionDataTaskWithResponse:response
                                                         body:responseBody
                                                        error:nil
                                               URLSessionMock:URLSessionMock
                                       requestValidationBlock:requestValidationBlock];
}

- (void)testRegisterNotifiesDelegateWhenInstallationIdEnabled {
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions GCMSenderID]).andReturn(@"123456789123");
  OCMStub([mockOptions projectID]).andReturn(@"test-project-id");
  OCMStub([mockOptions APIKey]).andReturn(@"test-api-key");
  OCMStub([mockOptions bundleID]).andReturn(@"com.google.FirebaseMessagingTest");
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(mockOptions);

  [self.messaging.tokenManager setValue:@"123456789123" forKey:@"fcmSenderID"];
  [self.messaging.tokenManager deleteAllTokensLocallyWithHandler:nil];
  [self.messaging.tokenManager setValue:nil forKey:@"defaultFCMToken"];

  // Setup APNs token.
  self.messaging.apnsTokenData = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  FIRMessagingAPNSInfo *mockAPNSInfo =
      [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:self.messaging.apnsTokenData isSandbox:YES];
  [self.messaging.tokenManager setValue:mockAPNSInfo forKey:@"currentAPNSInfo"];

  NSData *responseBody = [@"{\"name\":\"projects/test-project-id/registrations/fake-fid\"}"
      dataUsingEncoding:NSUTF8StringEncoding];
  [self
      setupV1RegistrationHttpCallWithMethod:@"POST"
                               responseBody:responseBody
                     requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                       // Assert the HTTP request is correct.
                       XCTAssertEqualObjects(sentRequest.URL.absoluteString,
                                             @"https://fcmregistrations.googleapis.com/v1/projects/"
                                             @"test-project-id/registrations");
                       XCTAssertEqualObjects(sentRequest.HTTPMethod, @"POST");
                       XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"X-Goog-Api-Key"],
                                             @"test-api-key");
                       XCTAssertEqualObjects(
                           sentRequest.allHTTPHeaderFields[@"X-Goog-Firebase-Installations-Auth"],
                           @"fis-auth-token");
                       NSDictionary *body =
                           [NSJSONSerialization JSONObjectWithData:sentRequest.HTTPBody
                                                           options:0
                                                             error:nil];
                       XCTAssertNotNil(body[@"ios"]);
                       XCTAssertEqualObjects(
                           body[@"ios"][@"apns_token"],
                           FIRMessagingStringForAPNSDeviceToken(self.messaging.apnsTokenData));
                       XCTAssertEqualObjects(body[@"ios"][@"apns_environment"], @"SANDBOX");
                       return YES;
                     }];

  // Setup message delegate.
  id mockDelegate = OCMProtocolMock(@protocol(FIRMessagingDelegate));
  self.messaging.delegate = mockDelegate;

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Delegate received registration notification."];
  OCMStub([mockDelegate messaging:OCMOCK_ANY didReceiveRegistration:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *installationId;
        [invocation getArgument:&installationId atIndex:3];
        XCTAssertEqualObjects(installationId, @"fake-fid");
        [expectation fulfill];
      });

  [self.messaging register];

  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testUnregisterNotifiesDelegateWhenInstallationIdEnabled {
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions GCMSenderID]).andReturn(@"123456789123");
  OCMStub([mockOptions projectID]).andReturn(@"test-project-id");
  OCMStub([mockOptions APIKey]).andReturn(@"test-api-key");
  OCMStub([mockOptions bundleID]).andReturn(@"com.google.FirebaseMessagingTest");
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(mockOptions);

  [self
      setupV1RegistrationHttpCallWithMethod:@"DELETE"
                               responseBody:nil
                     requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                       // Assert the HTTP request is correct.
                       XCTAssertEqualObjects(sentRequest.URL.absoluteString,
                                             @"https://fcmregistrations.googleapis.com/v1/projects/"
                                             @"test-project-id/registrations/fake-fid");
                       XCTAssertEqualObjects(sentRequest.HTTPMethod, @"DELETE");
                       XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"X-Goog-Api-Key"],
                                             @"test-api-key");
                       XCTAssertEqualObjects(
                           sentRequest.allHTTPHeaderFields[@"X-Goog-Firebase-Installations-Auth"],
                           @"fis-auth-token");
                       return YES;
                     }];

  // Setup message delegate.
  id mockDelegate = OCMProtocolMock(@protocol(FIRMessagingDelegate));
  self.messaging.delegate = mockDelegate;

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Delegate received unregister notification."];
  OCMStub([mockDelegate messaging:OCMOCK_ANY didUnregister:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *installationId;
        [invocation getArgument:&installationId atIndex:3];
        XCTAssertEqualObjects(installationId, @"fake-fid");
        [expectation fulfill];
      });

  [self.messaging unregister];

  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testAppStartNotifiesDelegateWhenBothAutoInitAndInstallationIdEnabled {
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // Both isInstallationIdEnabled and autoInitEnabled are YES.
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled])
      .andReturn(@YES);

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions GCMSenderID]).andReturn(@"123456789123");
  OCMStub([mockOptions projectID]).andReturn(@"test-project-id");
  OCMStub([mockOptions APIKey]).andReturn(@"test-api-key");
  OCMStub([mockOptions bundleID]).andReturn(@"com.google.FirebaseMessagingTest");
  OCMStub([mockOptions googleAppID]).andReturn(@"test-app-id");
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(mockOptions);

  NSData *responseBody = [@"{\"name\":\"projects/test-project-id/registrations/fake-fid\"}"
      dataUsingEncoding:NSUTF8StringEncoding];
  [self setupV1RegistrationHttpCallWithMethod:@"POST"
                                 responseBody:responseBody
                       requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                         return YES;
                       }];

  // Setup message delegate.
  id mockDelegate = OCMProtocolMock(@protocol(FIRMessagingDelegate));
  self.messaging.delegate = mockDelegate;

  XCTestExpectation *expectation = [self
      expectationWithDescription:@"Delegate received registration notification on app start."];
  OCMStub([mockDelegate messaging:OCMOCK_ANY didReceiveRegistration:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *installationId;
        [invocation getArgument:&installationId atIndex:3];
        XCTAssertEqualObjects(installationId, @"fake-fid");
        [expectation fulfill];
      });

  // Configure messaging and set APNs token to simulate app start.
  [self.messaging configureMessagingWithOptions:mockOptions];
  self.messaging.APNSToken = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];

  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end

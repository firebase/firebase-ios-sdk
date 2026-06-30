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
#import "FirebaseMessaging/Sources/FIRMessagingTopicOperation.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingFIDRegisterOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingFIDUnregisterOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

@interface FIRMessagingFIDRegisterOperation (ExposedForTest)
+ (void)resetSharedSession;
@end

@interface FIRMessagingFIDUnregisterOperation (ExposedForTest)
+ (void)resetSharedSession;
@end

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

- (void)retrieveTokenOrFidForSenderID:(nonnull NSString *)senderID
                           completion:(nullable FIRMessagingFCMTokenFetchCompletion)completion;
- (void)handleInstallationIDDidChangeNotification:(NSNotification *)notification;
@end

@interface FIRMessagingTest : XCTestCase

@property(nonatomic, readonly, strong) FIRMessaging *messaging;
@property(nonatomic, readwrite, strong) id mockMessaging;
@property(nonatomic, readwrite, strong) id mockInstanceID;
@property(nonatomic, readwrite, strong) id mockFirebaseApp;
@property(nonatomic, readwrite, strong) id mockTokenManager;
@property(nonatomic, strong) FIRMessagingTestUtilities *testUtil;
@property(nonatomic, readwrite, strong) id urlSessionMock;
@property(nonatomic, readwrite, strong) id bundleMock;

@end

@implementation FIRMessagingTest

- (void)clearPendingTopicSubscriptions {
  [[GULUserDefaults standardUserDefaults]
      removeObjectForKey:@"com.firebase.messaging.pending-subscriptions"];
}

- (void)setUp {
  [super setUp];
  [self clearPendingTopicSubscriptions];
  [FIRMessagingFIDRegisterOperation resetSharedSession];
  [FIRMessagingFIDUnregisterOperation resetSharedSession];

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
  [self.urlSessionMock stopMocking];
  self.urlSessionMock = nil;
  [self.bundleMock stopMocking];
  self.bundleMock = nil;
  _messaging = nil;
  [self clearPendingTopicSubscriptions];
  [[[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain]
      removePersistentDomainForName:kFIRMessagingDefaultsTestDomain];
  [FIRMessagingFIDRegisterOperation resetSharedSession];
  [FIRMessagingFIDUnregisterOperation resetSharedSession];
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
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled])
      .andReturn(nil);
  XCTAssertTrue(self.messaging.isAutoInitEnabled);

  self.messaging.autoInitEnabled = NO;
  XCTAssertFalse(self.messaging.isAutoInitEnabled);
}

- (void)testAutoInitEnableFlagOverrideGlobalFalse {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled])
      .andReturn(nil);
  XCTAssertTrue(self.messaging.isAutoInitEnabled);

  self.messaging.autoInitEnabled = NO;
  XCTAssertFalse(self.messaging.isAutoInitEnabled);
}

- (void)testAutoInitEnableGlobalDefaultTrue {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled])
      .andReturn(nil);

  XCTAssertTrue(self.messaging.isAutoInitEnabled);
}

- (void)testAutoInitEnableGlobalDefaultFalse {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(NO);
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled])
      .andReturn(nil);

  XCTAssertFalse(self.messaging.isAutoInitEnabled);
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

  self.urlSessionMock = OCMClassMock([NSURLSession class]);
  OCMStub(ClassMethod([self.urlSessionMock sessionWithConfiguration:[OCMArg any]]))
      .andReturn(self.urlSessionMock);

  // Setup the HTTP response.
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];

  id mockDataTask =
      [FIRURLSessionOCMockStub stubURLSessionDataTaskWithResponse:response
                                                             body:responseBody
                                                            error:nil
                                                   URLSessionMock:self.urlSessionMock
                                           requestValidationBlock:requestValidationBlock];
  OCMStub([mockDataTask setTaskDescription:OCMOCK_ANY]);
}

- (void)testRegisterNotifiesDelegateWhenInstallationIdEnabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
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

  XCTestExpectation *delegateExpectation =
      [self expectationWithDescription:@"Delegate received registration notification."];
  OCMStub([mockDelegate messaging:OCMOCK_ANY didReceiveRegistration:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *installationId;
        [invocation getArgument:&installationId atIndex:3];
        XCTAssertEqualObjects(installationId, @"fake-fid");
        [delegateExpectation fulfill];
      });

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Register completion called."];
  [self.messaging registerWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testRegisterNotifiesDelegateWhenCachedFidExists {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions GCMSenderID]).andReturn(@"123456789123");
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(mockOptions);

  [self.messaging.tokenManager setValue:@"123456789123" forKey:@"fcmSenderID"];
  [self.messaging.tokenManager setValue:@"fake-cached-fid" forKey:@"defaultFCMToken"];

  // Setup message delegate.
  id mockDelegate = OCMProtocolMock(@protocol(FIRMessagingDelegate));
  self.messaging.delegate = mockDelegate;

  XCTestExpectation *delegateExpectation =
      [self expectationWithDescription:@"Delegate received registration notification."];
  OCMStub([mockDelegate messaging:OCMOCK_ANY didReceiveRegistration:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *installationId;
        [invocation getArgument:&installationId atIndex:3];
        XCTAssertEqualObjects(installationId, @"fake-cached-fid");
        [delegateExpectation fulfill];
      });

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Register completion called."];
  [self.messaging registerWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testRegisterWithCompletionFailsWhenInstallationIdDisabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return NO.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@NO);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Register completion called."];
  [self.messaging registerWithCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidRequest);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testRegisterWithCompletionFailsWhenSenderIDMissing {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions GCMSenderID]).andReturn(nil);
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(mockOptions);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Register completion called."];
  [self.messaging registerWithCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kFIRMessagingErrorCodeMissingAuthorizedEntity);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testUnregisterNotifiesDelegateWhenInstallationIdEnabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
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

  XCTestExpectation *delegateExpectation =
      [self expectationWithDescription:@"Delegate received unregister notification."];
  OCMStub([mockDelegate messaging:OCMOCK_ANY didUnregister:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *installationId;
        [invocation getArgument:&installationId atIndex:3];
        XCTAssertEqualObjects(installationId, @"fake-fid");
        [delegateExpectation fulfill];
      });

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Unregister completion called."];
  [self.messaging unregisterWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testUnregisterWithCompletionFailsWhenInstallationIdDisabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return NO.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@NO);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Unregister completion called."];
  [self.messaging unregisterWithCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidRequest);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testUnregisterWithCompletionFailsWhenSenderIDMissing {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions GCMSenderID]).andReturn(nil);
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(mockOptions);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"Unregister completion called."];
  [self.messaging unregisterWithCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kFIRMessagingErrorCodeMissingAuthorizedEntity);
    [completionExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testAppStartNotifiesDelegateWhenBothAutoInitAndInstallationIdEnabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // Both isInstallationIdEnabled and autoInitEnabled are YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
      .andReturn(@YES);
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled])
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

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testSubscribeToTopicWhenInstallationIdEnabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
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

  // Configure messaging and set APNs token.
  [self.messaging configureMessagingWithOptions:mockOptions];
  self.messaging.APNSToken = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];

  // Setup installations ID & auth token.
  id installationIDArg = [OCMArg invokeBlockWithArgs:@"fake-fid", [NSNull null], nil];
  OCMStub([(FIRInstallations *)self.testUtil.mockInstallations
      installationIDWithCompletion:installationIDArg]);

  FIRInstallationsAuthTokenResult *mockAuthTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];
  id authTokenArg = [OCMArg invokeBlockWithArgs:mockAuthTokenResult, [NSNull null], nil];
  OCMStub(
      [(FIRInstallations *)self.testUtil.mockInstallations authTokenWithCompletion:authTokenArg]);

  id URLSessionMock = OCMClassMock([NSURLSession class]);

  id registrationOperationMock = OCMClassMock([FIRMessagingFIDRegisterOperation class]);
  OCMStub(ClassMethod([registrationOperationMock sharedSession])).andReturn(URLSessionMock);

  id topicOperationMock = OCMClassMock([FIRMessagingTopicOperation class]);
  OCMStub(ClassMethod([topicOperationMock sharedSession])).andReturn(URLSessionMock);

  // Setup the registration HTTP response.
  NSHTTPURLResponse *registrationResponse =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];
  NSData *registrationResponseBody =
      [@"{\"name\":\"projects/test-project-id/registrations/fake-fid\"}"
          dataUsingEncoding:NSUTF8StringEncoding];

  __block NSInteger callOrder = 0;
  __block NSInteger registrationCallIndex = -1;
  __block NSInteger subscriptionCallIndex = -1;

  id mockRegistrationDataTask = [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:registrationResponse
                                    body:registrationResponseBody
                                   error:nil
                          URLSessionMock:URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    registrationCallIndex = ++callOrder;
                    XCTAssertEqualObjects(sentRequest.URL.absoluteString,
                                          @"https://fcmregistrations.googleapis.com/v1/projects/"
                                          @"test-project-id/registrations");
                    XCTAssertEqualObjects(sentRequest.HTTPMethod, @"POST");
                    XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"X-Goog-Api-Key"],
                                          @"test-api-key");
                    XCTAssertEqualObjects(
                        sentRequest.allHTTPHeaderFields[@"X-Goog-Firebase-Installations-Auth"],
                        @"fis-auth-token");
                    return YES;
                  }];
  OCMStub([mockRegistrationDataTask setTaskDescription:OCMOCK_ANY]);

  // Setup the topic subscription HTTP response.
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];
  NSData *responseBody = [@"{\"topicName\":\"foobar\"}" dataUsingEncoding:NSUTF8StringEncoding];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Topic subscription HTTP request validated and completed."];

  id mockDataTask = [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response
                                    body:responseBody
                                   error:nil
                          URLSessionMock:URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    subscriptionCallIndex = ++callOrder;
                    XCTAssertEqualObjects(sentRequest.URL.absoluteString,
                                          @"https://fcmregistrations.googleapis.com/v1/projects/"
                                          @"test-project-id/registrations/fake-fid/"
                                          @"topicSubscriptions/foobar:subscribe");
                    XCTAssertEqualObjects(sentRequest.HTTPMethod, @"POST");
                    XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"X-Goog-Api-Key"],
                                          @"test-api-key");
                    XCTAssertEqualObjects(
                        sentRequest.allHTTPHeaderFields[@"X-Goog-Firebase-Installations-Auth"],
                        @"fis-auth-token");
                    XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"Accept"],
                                          @"application/json");
                    XCTAssertNil(sentRequest.HTTPBody);
                    return YES;
                  }];
  OCMStub([mockDataTask setTaskDescription:OCMOCK_ANY]);

  [self.messaging subscribeToTopic:@"foobar"
                        completion:^(NSError *_Nullable error) {
                          XCTAssertNil(error);
                          [expectation fulfill];
                        }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
  // Registration should be called first, then the topic subscription.
  XCTAssertEqual(registrationCallIndex, 1);
  XCTAssertEqual(subscriptionCallIndex, 2);
  [topicOperationMock stopMocking];
  [registrationOperationMock stopMocking];
}

- (void)testUnsubscribeFromTopicWhenInstallationIdEnabled {
  self.bundleMock = OCMPartialMock([NSBundle mainBundle]);
  // FirebaseMessaging.isInstallationIdEnabled should return YES.
  OCMStub([self.bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistInstallationIdEnabled])
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

  // Setup installations ID & auth token.
  id installationIDArg = [OCMArg invokeBlockWithArgs:@"fake-fid", [NSNull null], nil];
  OCMStub([(FIRInstallations *)self.testUtil.mockInstallations
      installationIDWithCompletion:installationIDArg]);

  FIRInstallationsAuthTokenResult *mockAuthTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];
  id authTokenArg = [OCMArg invokeBlockWithArgs:mockAuthTokenResult, [NSNull null], nil];
  OCMStub(
      [(FIRInstallations *)self.testUtil.mockInstallations authTokenWithCompletion:authTokenArg]);

  id URLSessionMock = OCMClassMock([NSURLSession class]);

  id topicOperationMock = OCMClassMock([FIRMessagingTopicOperation class]);
  OCMStub(ClassMethod([topicOperationMock sharedSession])).andReturn(URLSessionMock);

  // Setup the HTTP response.
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];
  NSData *responseBody = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];

  XCTestExpectation *expectation = [self
      expectationWithDescription:@"Topic unsubscription HTTP request validated and completed."];

  id mockDataTask = [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response
                                    body:responseBody
                                   error:nil
                          URLSessionMock:URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    XCTAssertEqualObjects(sentRequest.URL.absoluteString,
                                          @"https://fcmregistrations.googleapis.com/v1/projects/"
                                          @"test-project-id/registrations/fake-fid/"
                                          @"topicSubscriptions/foobar:unsubscribe");
                    XCTAssertEqualObjects(sentRequest.HTTPMethod, @"POST");
                    XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"X-Goog-Api-Key"],
                                          @"test-api-key");
                    XCTAssertEqualObjects(
                        sentRequest.allHTTPHeaderFields[@"X-Goog-Firebase-Installations-Auth"],
                        @"fis-auth-token");
                    XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"Accept"],
                                          @"application/json");
                    XCTAssertNil(sentRequest.HTTPBody);
                    return YES;
                  }];
  OCMStub([mockDataTask setTaskDescription:OCMOCK_ANY]);

  [self.messaging unsubscribeFromTopic:@"foobar"
                            completion:^(NSError *_Nullable error) {
                              XCTAssertNil(error);
                              [expectation fulfill];
                            }];

  [self waitForExpectationsWithTimeout:30.0 handler:nil];
  [topicOperationMock stopMocking];
}

- (void)testFIDChangeNotificationWhenDefaultFCMTokenIsNil {
  OCMStub([self.mockTokenManager defaultFCMToken]).andReturn(nil);

  id installationIDArg = [OCMArg invokeBlockWithArgs:@"fake-fid", [NSNull null], nil];
  OCMStub([(FIRInstallations *)self.testUtil.mockInstallations
      installationIDWithCompletion:installationIDArg]);

  // `defaultFCMToken` is nil, meaning the app hasn't registered with FCM yet.
  // Expect `retrieveTokenOrFidForSenderID` NOT to be called.
  [[self.mockMessaging reject] retrieveTokenOrFidForSenderID:OCMOCK_ANY completion:OCMOCK_ANY];

  [self.messaging handleInstallationIDDidChangeNotification:
                      [NSNotification notificationWithName:FIRInstallationIDDidChangeNotification
                                                    object:nil]];
  XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for main queue"];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:30 handler:nil];
}

- (void)testFIDChangeNotificationWhenDefaultFCMTokenIsNotNil {
  OCMStub([self.mockTokenManager defaultFCMToken]).andReturn(@"old-fake-fid");

  id installationIDArg = [OCMArg invokeBlockWithArgs:@"new-fake-fid", [NSNull null], nil];
  OCMStub([(FIRInstallations *)self.testUtil.mockInstallations
      installationIDWithCompletion:installationIDArg]);

  // `defaultFCMToken` is not nil, meaning the app has already registered with FCM.
  // Expect `retrieveTokenOrFidForSenderID` to be called to retrieve the new FID.
  XCTestExpectation *retrieveTokenExpectation =
      [self expectationWithDescription:@"retrieveTokenOrFidForSenderID should be called"];
  [[[self.mockMessaging expect] andDo:^(NSInvocation *invocation) {
    [retrieveTokenExpectation fulfill];
  }] retrieveTokenOrFidForSenderID:OCMOCK_ANY completion:OCMOCK_ANY];

  [self.messaging handleInstallationIDDidChangeNotification:
                      [NSNotification notificationWithName:FIRInstallationIDDidChangeNotification
                                                    object:nil]];

  [self waitForExpectationsWithTimeout:30 handler:nil];
}

@end

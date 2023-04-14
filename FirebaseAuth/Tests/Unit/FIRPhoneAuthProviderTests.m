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

#import <TargetConditionals.h>
#if TARGET_OS_IOS
#if TODO_SWIFT
#import <OCMock/OCMock.h>
#import <SafariServices/SafariServices.h>
#import <XCTest/XCTest.h>
@import FirebaseAuth;
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
// #import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
@import FirebaseAuth;
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredentialManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthNotificationManager.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeAppCheck.h"
#import "FirebaseAuth/Tests/Unit/OCMStubRecorder+FIRAuthUnitTests.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kTestPhoneNumber
    @brief A testing phone number.
 */
static NSString *const kTestPhoneNumber = @"55555555";

/** @var kTestInvalidPhoneNumber
    @brief An invalid testing phone number.
 */
static NSString *const kTestInvalidPhoneNumber = @"555+!*55555";

/** @var kTestVerificationID
    @brief A testing verfication ID.
 */
static NSString *const kTestVerificationID = @"verificationID";

/** @var kTestReceipt
    @brief A fake receipt for testing.
 */
static NSString *const kTestReceipt = @"receipt";

/** @var kTestSecret
    @brief A fake secret for testing.
 */
static NSString *const kTestSecret = @"secret";

/** @var kTestOldReceipt
    @brief A fake old receipt for testing.
 */
static NSString *const kTestOldReceipt = @"old_receipt";

/** @var kTestOldSecret
    @brief A fake old secret for testing.
 */
static NSString *const kTestOldSecret = @"old_secret";

/** @var kTestVerificationCode
    @brief A fake verfication code.
 */
static NSString *const kTestVerificationCode = @"verificationCode";

/** @var kFakeClientID
    @brief A fake client ID.
 */
static NSString *const kFakeClientID = @"123456.apps.googleusercontent.com";

/** @var kFakeReverseClientID
    @brief The dot-reversed version of the fake client ID.
 */
static NSString *const kFakeReverseClientID = @"com.googleusercontent.apps.123456";

/** @var kFakeFirebaseAppID
    @brief A fake Firebase app ID.
 */
static NSString *const kFakeFirebaseAppID = @"1:123456789:ios:123abc456def";

/** @var kFakeEncodedFirebaseAppID
    @brief A fake encoded Firebase app ID to be used as a custom URL scheme.
 */
static NSString *const kFakeEncodedFirebaseAppID = @"app-1-123456789-ios-123abc456def";

/** @var kFakeBundleID
    @brief A fake bundle ID.
 */
static NSString *const kFakeBundleID = @"com.firebaseapp.example";

/** @var kFakeAPIKey
    @brief A fake API key.
 */
static NSString *const kFakeAPIKey = @"asdfghjkl";

/** @var kFakeAuthorizedDomain
    @brief A fake authorized domain for the app.
 */
static NSString *const kFakeAuthorizedDomain = @"test.firebaseapp.com";

/** @var kFakeReCAPTCHAToken
    @brief A fake reCAPTCHA token.
 */
static NSString *const kFakeReCAPTCHAToken = @"fakeReCAPTCHAToken";

/** @var kFakeRedirectURLStringWithReCAPTCHAToken
    @brief The format for a fake redirect URL string (minus the scheme) that contains the fake
   reCAPTCHA token above.
 */
static NSString *const kFakeRedirectURLStringWithReCAPTCHAToken =
    @"://firebaseauth/"
    @"link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3FauthType%"
    @"3DverifyApp%26recaptchaToken%3DfakeReCAPTCHAToken";

/** @var kFakeRedirectURLStringInvalidClientID
    @brief The format for a fake redirect URL string with an invalid client error.
 */
static NSString *const kFakeRedirectURLStringInvalidClientID =
    @"com.googleusercontent.apps.1"
     "23456://firebaseauth/"
     "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal"
     "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Finvalid-oauth-client-id%2522%"
     "252"
     "C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%"
     "252"
     "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%"
     "26"
     "authType%3DverifyApp";

/** @var kFakeRedirectURLStringWebNetworkRequestFailed
    @brief The format for a fake redirect URL string with a web network request failed error.
 */
static NSString *const kFakeRedirectURLStringWebNetworkRequestFailed =
    @"com.googleusercontent.apps"
     ".123456://firebaseauth/"
     "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fc"
     "allback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Fnetwork-request-failed%2522%"
     "25"
     "2C%2522message%2522%253A%2522The%2520network%2520request%2520failed%2520.%2522%257D%"
     "26authType"
     "%3DverifyApp";

/** @var kFakeRedirectURLStringWebInternalError
    @brief The format for a fake redirect URL string with an internal web error.
 */
static NSString *const kFakeRedirectURLStringWebInternalError =
    @"com.googleusercontent.apps.1"
     "23456://firebaseauth/"
     "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal"
     "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Finternal-error%2522%252C%"
     "2522mes"
     "sage%2522%253A%2522Internal%2520error%2520.%2522%257D%26authType%3DverifyApp";

/** @var kFakeRedirectURLStringUnknownError
    @brief The format for a fake redirect URL string with unknown error response.
 */
static NSString *const kFakeRedirectURLStringUnknownError =
    @"com.googleusercontent.apps.1"
     "23456://firebaseauth/"
     "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal"
     "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Funknown-error-id%2522%252"
     "C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%"
     "252"
     "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%"
     "26"
     "authType%3DverifyApp";

/** @var kFakeRedirectURLStringUnstructuredError
    @brief The format for a fake redirect URL string with unstructured error response.
 */
static NSString *const kFakeRedirectURLStringUnstructuredError =
    @"com.googleusercontent.apps.1"
     "23456://firebaseauth/"
     "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal"
     "lback%3FfirebaseError%3D%257B%2522unstructuredcode%2522%253A%2522auth%252Funknown-error-id%"
     "2522%252"
     "C%2522unstructuredmessage%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%"
     "2520either%252"
     "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%"
     "26"
     "authType%3DverifyApp";

/** @var kTestTimeout
    @brief A fake timeout value for waiting for push notification.
 */
static const NSTimeInterval kTestTimeout = 5;

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 2;

/** @class FIRPhoneAuthProviderTests
    @brief Tests for @c FIRPhoneAuthProvider
 */
@interface FIRPhoneAuthProviderTests : XCTestCase
@end

@implementation FIRPhoneAuthProviderTests {
  /** @var _mockBackend
      @brief The mock @c FIRAuthBackendImplementation .
   */
  id _mockBackend;

  /** @var _provider
      @brief The @c FIRPhoneAuthProvider instance under test.
   */
  FIRPhoneAuthProvider *_provider;

  /** @var _mockAuth
      @brief The mock @c FIRAuth instance associated with @c _provider .
   */
  id _mockAuth;

  /** @var _mockApp
      @brief The mock @c FIRApp instance associated with @c _mockAuth .
   */
  id _mockApp;

  /** @var _mockOptions
      @brief The mock @c FIROptions instance associated with @c _mockApp.
   */
  id _mockOptions;

  /** @var _mockAPNSTokenManager
      @brief The mock @c FIRAuthAPNSTokenManager instance associated with @c _mockAuth .
   */
  id _mockAPNSTokenManager;

  /** @var _mockAppCredentialManager
      @brief The mock @c FIRAuthAppCredentialManager instance associated with @c _mockAuth .
   */
  id _mockAppCredentialManager;

  /** @var _mockNotificationManager
      @brief The mock @c FIRAuthNotificationManager instance associated with @c _mockAuth .
   */
  id _mockNotificationManager;

  /** @var _mockURLPresenter
      @brief The mock @c FIRAuthURLPresenter instance associated with @c _mockAuth .
   */
  id _mockURLPresenter;

  /** @var _mockRequestConfiguration
      @brief The mock @c FIRAuthRequestConfiguration instance associated with @c _mockAuth.
   */
  id _mockRequestConfiguration;
}
#ifdef TODO_SWIFT
- (void)setUp {
  [super setUp];
  _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
  [FIRAuthBackend setBackendImplementation:_mockBackend];
  _mockAuth = OCMClassMock([FIRAuth class]);
  _mockApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockAuth app]).andReturn(_mockApp);
  _mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([(FIRApp *)_mockApp options]).andReturn(_mockOptions);
  OCMStub([_mockOptions googleAppID]).andReturn(kFakeFirebaseAppID);
  _mockAPNSTokenManager = OCMClassMock([FIRAuthAPNSTokenManager class]);
  OCMStub([_mockAuth tokenManager]).andReturn(_mockAPNSTokenManager);
  _mockAppCredentialManager = OCMClassMock([FIRAuthAppCredentialManager class]);
  OCMStub([_mockAuth appCredentialManager]).andReturn(_mockAppCredentialManager);
  _mockNotificationManager = OCMClassMock([FIRAuthNotificationManager class]);
  OCMStub([_mockAuth notificationManager]).andReturn(_mockNotificationManager);
  _mockURLPresenter = OCMClassMock([FIRAuthURLPresenter class]);
  OCMStub([_mockAuth authURLPresenter]).andReturn(_mockURLPresenter);
  _mockRequestConfiguration = OCMClassMock([FIRAuthRequestConfiguration class]);
  OCMStub([_mockAuth requestConfiguration]).andReturn(_mockRequestConfiguration);
  OCMStub([_mockRequestConfiguration APIKey]).andReturn(kFakeAPIKey);
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithrpcIssuer:nil];
  [super tearDown];
}

// We're still testing deprecated `verifyPhoneNumber:completion:` extensively.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#ifdef TODO_SWIFT
/** @fn testSendVerificationCodeFailedRetry
    @brief Tests failed retry after failing to send verification code.
 */
- (void)testSendVerificationCodeFailedRetry {
  [self mockBundleWithURLScheme:kFakeReverseClientID];
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });

  // Expect twice due to null check consumes one expectation.
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  NSData *data = [@"!@#$%^" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];

  // Expect first sendVerificationCode request to the backend, with request containing old app
  // credential.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertEqualObjects(request.appCredential.receipt, kTestOldReceipt);
        XCTAssertEqualObjects(request.appCredential.secret, kTestOldSecret);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          callback(nil, [FIRAuthErrorUtils invalidAppCredentialWithMessage:nil]);
        });
      });

  // Expect send verification code request to the backend, with request containing new app
  // credential data.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
        XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          callback(nil, [FIRAuthErrorUtils invalidAppCredentialWithMessage:nil]);
        });
      });

  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        callback(token, nil);
      });
  // Expect verify client request to the backend.
  OCMExpect([_mockBackend verifyClient:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyClientRequest *request, FIRVerifyClientResponseCallback callback) {
        XCTAssertEqualObjects(request.appToken, @"21402324255E");
        XCTAssertFalse(request.isSandbox);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyClientResponse = OCMClassMock([FIRVerifyClientResponse class]);
          OCMStub([mockVerifyClientResponse receipt]).andReturn(kTestReceipt);
          OCMStub([mockVerifyClientResponse suggestedTimeOutDate])
              .andReturn([NSDate dateWithTimeIntervalSinceNow:kTestTimeout]);
          callback(mockVerifyClientResponse, nil);
        });
      });

  // Mock receiving of push notification.
  OCMStub([_mockAppCredentialManager didStartVerificationWithReceipt:OCMOCK_ANY
                                                             timeout:0
                                                            callback:OCMOCK_ANY])
      .ignoringNonObjectArgs()
      .andCallIdDoubleIdBlock(^(NSString *receipt, NSTimeInterval timeout,
                                FIRAuthAppCredentialCallback callback) {
        XCTAssertEqualObjects(receipt, kTestReceipt);
        // Unfortunately 'ignoringNonObjectArgs' means the real value for 'timeout' doesn't get
        // passed into the block either, so we can't verify it here.
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          callback([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(verificationID);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeInternalError);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
  OCMVerifyAll(_mockAPNSTokenManager);
}

/** @fn testSendVerificationCodeSuccessFulRetry
    @brief Tests successful retry after failing to send verification code.
 */
- (void)testSendVerificationCodeSuccessfulRetry {
  [self mockBundleWithURLScheme:kFakeReverseClientID];
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });

  // Expect twice due to null check consumes one expectation.
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  NSData *data = [@"!@#$%^" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];

  // Expect first sendVerificationCode request to the backend, with request containing old app
  // credential.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertEqualObjects(request.appCredential.receipt, kTestOldReceipt);
        XCTAssertEqualObjects(request.appCredential.secret, kTestOldSecret);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          callback(nil, [FIRAuthErrorUtils invalidAppCredentialWithMessage:nil]);
        });
      });

  // Expect send verification code request to the backend, with request containing new app
  // credential data.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
        XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockSendVerificationCodeResponse =
              OCMClassMock([FIRSendVerificationCodeResponse class]);
          OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
          callback(mockSendVerificationCodeResponse, nil);
        });
      });

  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        callback(token, nil);
      });
  // Expect verify client request to the backend.
  OCMExpect([_mockBackend verifyClient:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyClientRequest *request, FIRVerifyClientResponseCallback callback) {
        XCTAssertEqualObjects(request.appToken, @"21402324255E");
        XCTAssertFalse(request.isSandbox);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyClientResponse = OCMClassMock([FIRVerifyClientResponse class]);
          OCMStub([mockVerifyClientResponse receipt]).andReturn(kTestReceipt);
          OCMStub([mockVerifyClientResponse suggestedTimeOutDate])
              .andReturn([NSDate dateWithTimeIntervalSinceNow:kTestTimeout]);
          callback(mockVerifyClientResponse, nil);
        });
      });

  // Mock receiving of push notification.
  OCMStub([_mockAppCredentialManager didStartVerificationWithReceipt:OCMOCK_ANY
                                                             timeout:0
                                                            callback:OCMOCK_ANY])
      .ignoringNonObjectArgs()
      .andCallIdDoubleIdBlock(^(NSString *receipt, NSTimeInterval timeout,
                                FIRAuthAppCredentialCallback callback) {
        XCTAssertEqualObjects(receipt, kTestReceipt);
        // Unfortunately 'ignoringNonObjectArgs' means the real value for 'timeout' doesn't get
        // passed into the block either, so we can't verify it here.
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          callback([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(verificationID, kTestVerificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
  OCMVerifyAll(_mockAPNSTokenManager);
}

- (void)mockBundleWithURLScheme:(NSString *)URLScheme {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ URLScheme ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);
}
}
#endif
#endif
#pragma clang diagnostic pop  // ignored "-Wdeprecated-declarations"

@end

NS_ASSUME_NONNULL_END
#endif
#endif

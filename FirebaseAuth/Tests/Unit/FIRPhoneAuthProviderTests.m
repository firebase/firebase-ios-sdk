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

#import <SafariServices/SafariServices.h>
#import <XCTest/XCTest.h>
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuth.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthSettings.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthUIDelegate.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRPhoneAuthProvider.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "OCMock.h"

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/AuthProvider/FIRAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/AuthProvider/Phone/FIRPhoneAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthRequestConfiguration.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientResponse.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSToken.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSTokenManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredentialManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthNotificationManager.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthURLPresenter.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthWebUtils.h"
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
}

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
  id mockRequestConfiguration = OCMClassMock([FIRAuthRequestConfiguration class]);
  OCMStub([_mockAuth requestConfiguration]).andReturn(mockRequestConfiguration);
  OCMStub([mockRequestConfiguration APIKey]).andReturn(kFakeAPIKey);
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

// We're still testing deprecated `verifyPhoneNumber:completion:` extensively.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

/** @fn testCredentialWithVerificationID
    @brief Tests the @c credentialWithToken method to make sure that it returns a valid
        FIRAuthCredential instance.
 */
- (void)testCredentialWithVerificationID {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  FIRPhoneAuthCredential *credential =
      [_provider credentialWithVerificationID:kTestVerificationID
                             verificationCode:kTestVerificationCode];
  XCTAssertEqualObjects(credential.verificationID, kTestVerificationID);
  XCTAssertEqualObjects(credential.verificationCode, kTestVerificationCode);
  XCTAssertNil(credential.temporaryProof);
  XCTAssertNil(credential.phoneNumber);
}

/** @fn testVerifyEmptyPhoneNumber
    @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an empty phone
        number was provided.
 */
- (void)testVerifyEmptyPhoneNumber {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Empty phone number is checked on the client side so no backend RPC is mocked.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:@""
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertNotNil(error);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeMissingPhoneNumber);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testVerifyInvalidPhoneNumber
    @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an invalid phone
        number was provided.
 */
- (void)testVerifyInvalidPhoneNumber {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMStub([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
        XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          callback(nil, [FIRAuthErrorUtils invalidPhoneNumberErrorWithMessage:nil]);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(verificationID);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidPhoneNumber);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testVerifyPhoneNumber
    @brief Tests a successful invocation of @c verifyPhoneNumber:completion:.
 */
- (void)testVerifyPhoneNumber {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMStub([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
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

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(verificationID, kTestVerificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testVerifyPhoneNumberInTestMode
    @brief Tests a successful invocation of @c verifyPhoneNumber:completion: when app verification
        is disabled.
 */
- (void)testVerifyPhoneNumberInTestMode {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Disable app verification.
  FIRAuthSettings *settings = [[FIRAuthSettings alloc] init];
  settings.appVerificationDisabledForTesting = YES;
  OCMStub([_mockAuth settings]).andReturn(settings);
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        // Assert that the app credential is nil when in test mode.
        XCTAssertNil(request.appCredential);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockSendVerificationCodeResponse =
              OCMClassMock([FIRSendVerificationCodeResponse class]);
          OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
          callback(mockSendVerificationCodeResponse, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(verificationID, kTestVerificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testVerifyPhoneNumberInTestModeFailure
    @brief Tests a failed invocation of @c verifyPhoneNumber:completion: when app verification
        is disabled.
 */
- (void)testVerifyPhoneNumberInTestModeFailure {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Disable app verification.
  FIRAuthSettings *settings = [[FIRAuthSettings alloc] init];
  settings.appVerificationDisabledForTesting = YES;
  OCMStub([_mockAuth settings]).andReturn(settings);
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        // Assert that the app credential is nil when in test mode.
        XCTAssertNil(request.appCredential);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          NSError *underlying = [NSError errorWithDomain:@"Test Error" code:1 userInfo:nil];
          callback(nil, [FIRAuthErrorUtils networkErrorWithUnderlyingError:underlying]);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(verificationID);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeNetworkError);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow
    @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion:.
 */
- (void)testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow {
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeEncodedFirebaseAppID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");

        NSURLComponents *actualURLComponents = [NSURLComponents componentsWithURL:presentURL
                                                          resolvingAgainstBaseURL:NO];
        NSArray<NSURLQueryItem *> *queryItems = [actualURLComponents queryItems];
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"ibi" from:queryItems],
                              kFakeBundleID);
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"appId" from:queryItems],
                              kFakeFirebaseAppID);
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"apiKey" from:queryItems],
                              kFakeAPIKey);
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"authType" from:queryItems],
                              @"verifyApp");
        XCTAssertNotNil([FIRAuthWebUtils queryItemValue:@"v" from:queryItems]);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeEncodedFirebaseAppID
                                 stringByAppendingString:kFakeRedirectURLStringWithReCAPTCHAToken]];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:[FIRAuthWebUtils queryItemValue:@"eventId" from:queryItems]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:[kFakeEncodedFirebaseAppID
                                              stringByAppendingString:
                                                  kFakeRedirectURLStringWithReCAPTCHAToken]],
                     nil);
        });
      });

  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertNil(request.appCredential);
        XCTAssertEqualObjects(request.reCAPTCHAToken, kFakeReCAPTCHAToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockSendVerificationCodeResponse =
              OCMClassMock([FIRSendVerificationCodeResponse class]);
          OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
          callback(mockSendVerificationCodeResponse, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:mockUIDelegate
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(verificationID, kTestVerificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateClientIdFlow
    @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion:.
 */
- (void)testVerifyPhoneNumberUIDelegateClientIdFlow {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");

        NSURLComponents *actualURLComponents = [NSURLComponents componentsWithURL:presentURL
                                                          resolvingAgainstBaseURL:NO];
        NSArray<NSURLQueryItem *> *queryItems = [actualURLComponents queryItems];
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"ibi" from:queryItems],
                              kFakeBundleID);
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"clientId" from:queryItems],
                              kFakeClientID);
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"apiKey" from:queryItems],
                              kFakeAPIKey);
        XCTAssertEqualObjects([FIRAuthWebUtils queryItemValue:@"authType" from:queryItems],
                              @"verifyApp");
        XCTAssertNotNil([FIRAuthWebUtils queryItemValue:@"v" from:queryItems]);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeReverseClientID
                                 stringByAppendingString:kFakeRedirectURLStringWithReCAPTCHAToken]];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:[FIRAuthWebUtils queryItemValue:@"eventId" from:queryItems]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:[kFakeReverseClientID
                                              stringByAppendingString:
                                                  kFakeRedirectURLStringWithReCAPTCHAToken]],
                     nil);
        });
      });

  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
        XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
        XCTAssertNil(request.appCredential);
        XCTAssertEqualObjects(request.reCAPTCHAToken, kFakeReCAPTCHAToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockSendVerificationCodeResponse =
              OCMClassMock([FIRSendVerificationCodeResponse class]);
          OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
          callback(mockSendVerificationCodeResponse, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:mockUIDelegate
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(verificationID, kTestVerificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateInvalidClientID
    @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
        invalid client ID error.
 */
- (void)testVerifyPhoneNumberUIDelegateInvalidClientID {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:kFakeRedirectURLStringInvalidClientID], nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:mockUIDelegate
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidClientID);
                      XCTAssertNil(verificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateWebNetworkRequestFailed
    @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in a web
        network request failed error.
 */
- (void)testVerifyPhoneNumberUIDelegateNetworkRequestFailed {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:kFakeRedirectURLStringWebNetworkRequestFailed], nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:mockUIDelegate
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeWebNetworkRequestFailed);
                      XCTAssertNil(verificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateWebInternalError
    @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in a web
        internal error.
 */
- (void)testVerifyPhoneNumberUIDelegateWebInternalError {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:kFakeRedirectURLStringWebInternalError], nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:mockUIDelegate
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeWebInternalError);
                      XCTAssertNil(verificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateUnexpectedError
    @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
        invalid client ID.
 */
- (void)testVerifyPhoneNumberUIDelegateUnexpectedError {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:kFakeRedirectURLStringUnknownError], nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      verifyPhoneNumber:kTestPhoneNumber
             UIDelegate:mockUIDelegate
             completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
               XCTAssertTrue([NSThread isMainThread]);
               XCTAssertEqual(error.code, FIRAuthErrorCodeAppVerificationUserInteractionFailure);
               XCTAssertNil(verificationID);
               [expectation fulfill];
             }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateUnstructuredError
    @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
        error being surfaced with a default NSLocalizedFailureReasonErrorKey due to an unexpected
        structure of the error response.
 */
- (void)testVerifyPhoneNumberUIDelegateUnstructuredError {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion([NSURL URLWithString:kFakeRedirectURLStringUnstructuredError], nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      verifyPhoneNumber:kTestPhoneNumber
             UIDelegate:mockUIDelegate
             completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
               XCTAssertTrue([NSThread isMainThread]);
               XCTAssertEqual(error.code, FIRAuthErrorCodeAppVerificationUserInteractionFailure);
               XCTAssertNil(verificationID);
               [expectation fulfill];
             }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyPhoneNumberUIDelegateRaiseException
    @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
        exception.
 */
- (void)testVerifyPhoneNumberUIDelegateRaiseException {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ @"badscheme" ]}
  ]);
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));
  XCTAssertThrows([_provider
      verifyPhoneNumber:kTestPhoneNumber
             UIDelegate:mockUIDelegate
             completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
               XCTFail(@"Shouldn't call completion here.");
             }]);
}

/** @fn testNotForwardingNotification
    @brief Tests returning an error for the app failing to forward notification.
 */
- (void)testNotForwardingNotification {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(NO);
      });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertNil(verificationID);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeNotificationNotForwarded);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testMissingAPNSToken
    @brief Tests returning an error for the app failing to provide an APNS device token.
 */
- (void)testMissingAPNSToken {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  // Simulate missing app token error.
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) {
        NSError *error = [NSError errorWithDomain:FIRAuthErrorDomain
                                             code:FIRAuthErrorCodeMissingAppToken
                                         userInfo:nil];
        callback(nil, error);
      });
  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(nil, [NSError errorWithDomain:FIRAuthErrorDomain
                                              code:FIRAuthErrorCodeMissingAppToken
                                          userInfo:nil]);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:mockUIDelegate
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
                      XCTAssertEqual(error.code, FIRAuthErrorCodeMissingAppToken);
                      XCTAssertNil(verificationID);
                      [expectation fulfill];
                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testVerifyClient
    @brief Tests verifying client before sending verification code.
 */
- (void)testVerifyClient {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) {
        callback(YES);
      });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  NSData *data = [@"!@#$%^" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];
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
  OCMExpect([_mockAppCredentialManager didStartVerificationWithReceipt:OCMOCK_ANY
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
  // Expect send verification code request to the backend.
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

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    UIDelegate:nil
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
                      XCTAssertTrue([NSThread isMainThread]);
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

/** @fn testSendVerificationCodeFailedRetry
    @brief Tests failed retry after failing to send verification code.
 */
- (void)testSendVerificationCodeFailedRetry {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

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
- (void)testSendVerificationCodeSuccessFulRetry {
  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];

  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

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

#pragma clang diagnostic pop  // ignored "-Wdeprecated-declarations"

@end

NS_ASSUME_NONNULL_END

#endif

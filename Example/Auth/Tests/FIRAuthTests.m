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

#import "FIRAppInternal.h"
#import "EmailPassword/FIREmailAuthProvider.h"
#import "Google/FIRGoogleAuthProvider.h"
#import "Phone/FIRPhoneAuthCredential.h"
#import "Phone/FIRPhoneAuthProvider.h"
#import "FIRAdditionalUserInfo.h"
#import "FIRAuth_Internal.h"
#import "FIRAuthErrorUtils.h"
#import "FIRAuthDispatcher.h"
#import "FIRAuthGlobalWorkQueue.h"
#import "FIRUser_Internal.h"
#import "FIRAuthBackend.h"
#import "FIRCreateAuthURIRequest.h"
#import "FIRCreateAuthURIResponse.h"
#import "FIRGetAccountInfoRequest.h"
#import "FIRGetAccountInfoResponse.h"
#import "FIRGetOOBConfirmationCodeRequest.h"
#import "FIRGetOOBConfirmationCodeResponse.h"
#import "FIRSecureTokenRequest.h"
#import "FIRSecureTokenResponse.h"
#import "FIRResetPasswordRequest.h"
#import "FIRResetPasswordResponse.h"
#import "FIRSetAccountInfoRequest.h"
#import "FIRSetAccountInfoResponse.h"
#import "FIRSignUpNewUserRequest.h"
#import "FIRSignUpNewUserResponse.h"
#import "FIRVerifyCustomTokenRequest.h"
#import "FIRVerifyCustomTokenResponse.h"
#import "FIRVerifyAssertionRequest.h"
#import "FIRVerifyAssertionResponse.h"
#import "FIRVerifyPasswordRequest.h"
#import "FIRVerifyPasswordResponse.h"
#import "FIRVerifyPhoneNumberRequest.h"
#import "FIRVerifyPhoneNumberResponse.h"
#import "FIRApp+FIRAuthUnitTests.h"
#import "OCMStubRecorder+FIRAuthUnitTests.h"
#import <OCMock/OCMock.h>

/** @var kFirebaseAppName1
    @brief A fake Firebase app name.
 */
static NSString *const kFirebaseAppName1 = @"FIREBASE_APP_NAME_1";

/** @var kFirebaseAppName2
    @brief Another fake Firebase app name.
 */
static NSString *const kFirebaseAppName2 = @"FIREBASE_APP_NAME_2";

/** @var kAPIKey
    @brief The fake API key.
 */
static NSString *const kAPIKey = @"FAKE_API_KEY";

/** @var kAccessToken
    @brief The fake access token.
 */
static NSString *const kAccessToken = @"ACCESS_TOKEN";

/** @var kNewAccessToken
    @brief Another fake access token used to simulate token refreshed via automatic token refresh.
 */
NSString *kNewAccessToken = @"NewAccessToken";

/** @var kAccessTokenValidInterval
    @brief The time to live for the fake access token.
 */
static const NSTimeInterval kAccessTokenTimeToLive = 60 * 60;

/** @var kTestTokenExpirationTimeInterval
    @brief The fake time interval that it takes a token to expire.
 */
static const NSTimeInterval kTestTokenExpirationTimeInterval = 55 * 60;

/** @var kRefreshToken
    @brief The fake refresh token.
 */
static NSString *const kRefreshToken = @"REFRESH_TOKEN";

/** @var kEmail
    @brief The fake user email.
 */
static NSString *const kEmail = @"user@company.com";

/** @var kPassword
    @brief The fake user password.
 */
static NSString *const kPassword = @"!@#$%^";

/** @var kPasswordHash
    @brief The fake user password hash.
 */
static NSString *const kPasswordHash = @"UkVEQUNURUQ=";

/** @var kLocalID
    @brief The fake local user ID.
 */
static NSString *const kLocalID = @"LOCAL_ID";

/** @var kDisplayName
    @brief The fake user display name.
 */
static NSString *const kDisplayName = @"User Doe";

/** @var kGoogleUD
    @brief The fake user ID under Google Sign-In.
 */
static NSString *const kGoogleID = @"GOOGLE_ID";

/** @var kGoogleEmail
    @brief The fake user email under Google Sign-In.
 */
static NSString *const kGoogleEmail = @"user@gmail.com";

/** @var kGoogleDisplayName
    @brief The fake user display name under Google Sign-In.
 */
static NSString *const kGoogleDisplayName = @"Google Doe";

/** @var kGoogleAccessToken
    @brief The fake access token from Google Sign-In.
 */
static NSString *const kGoogleAccessToken = @"GOOGLE_ACCESS_TOKEN";

/** @var kGoogleIDToken
    @brief The fake ID token from Google Sign-In.
 */
static NSString *const kGoogleIDToken = @"GOOGLE_ID_TOKEN";

/** @var kCustomToken
    @brief The fake custom token to sign in.
 */
static NSString *const kCustomToken = @"CUSTOM_TOKEN";

/** @var kVerificationCode
    @brief Fake verification code used for testing.
 */
static NSString *const kVerificationCode = @"12345678";

/** @var kVerificationID
    @brief Fake verification ID for testing.
 */
static NSString *const kVerificationID = @"55432";

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 1;

/** @var kWaitInterval
    @brief The time waiting for background tasks to finish before continue when necessary.
 */
static const NSTimeInterval kWaitInterval = .5;

/** @class FIRAuthTests
    @brief Tests for @c FIRAuth.
 */
@interface FIRAuthTests : XCTestCase
@end
@implementation FIRAuthTests {

  /** @var _mockBackend
      @brief The mock @c FIRAuthBackendImplementation .
   */
  id _mockBackend;

   /** @var _FIRAuthDispatcherCallback
      @brief Used to save a task from FIRAuthDispatcher to be executed later.
   */
  __block void (^_Nonnull _FIRAuthDispatcherCallback)(void);
}

/** @fn googleProfile
    @brief The fake user profile under additional user data in @c FIRVerifyAssertionResponse.
 */
+ (NSDictionary *)googleProfile {
  static NSDictionary *kGoogleProfile = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kGoogleProfile = @{
      @"iss": @"https://accounts.google.com\\",
      @"email": kGoogleEmail,
      @"given_name": @"User",
      @"family_name": @"Doe"
    };
  });
  return kGoogleProfile;
}

- (void)setUp {
  [super setUp];
  _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
  [FIRAuthBackend setBackendImplementation:_mockBackend];
  [FIRApp resetAppForAuthUnitTests];

  // Set FIRAuthDispatcher implementation in order to save the token refresh task for later
  // execution.
  [[FIRAuthDispatcher sharedInstance]
      setDispatchAfterImplementation:^(NSTimeInterval delay,
                                       dispatch_queue_t  _Nonnull queue,
                                       void (^task)(void)) {
    XCTAssertNotNil(task);
    XCTAssert(delay > 0);
    XCTAssertEqualObjects(FIRAuthGlobalWorkQueue(), queue);
    _FIRAuthDispatcherCallback = task;
  }];
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [[FIRAuthDispatcher sharedInstance] setDispatchAfterImplementation:nil];
  [super tearDown];
}

#pragma mark - Life Cycle Tests

/** @fn testSingleton
    @brief Verifies the @c auth method behaves like a singleton.
 */
- (void)testSingleton {
  FIRAuth *auth1 = [FIRAuth auth];
  XCTAssertNotNil(auth1);
  FIRAuth *auth2 = [FIRAuth auth];
  XCTAssertEqual(auth1, auth2);
}

/** @fn testDefaultAuth
    @brief Verifies the @c auth method associates with the default Firebase app.
 */
- (void)testDefaultAuth {
  FIRAuth *auth1 = [FIRAuth auth];
  FIRAuth *auth2 = [FIRAuth authWithApp:[FIRApp defaultApp]];
  XCTAssertEqual(auth1, auth2);
  XCTAssertEqual(auth1.app, [FIRApp defaultApp]);
}

/** @fn testNilAppException
    @brief Verifies the @c auth method raises an exception if the default FIRApp is not configured.
 */
- (void)testNilAppException {
  [FIRApp resetApps];
  XCTAssertThrows([FIRAuth auth]);
}

/** @fn testAppAPIkey
    @brief Verifies the API key is correctly copied from @c FIRApp to @c FIRAuth .
 */
- (void)testAppAPIkey {
  FIRAuth *auth = [FIRAuth auth];
  XCTAssertEqualObjects(auth.APIKey, kAPIKey);
}

/** @fn testAppAssociation
    @brief Verifies each @c FIRApp instance associates with a @c FIRAuth .
 */
- (void)testAppAssociation {
  FIRApp *app1 = [self app1];
  FIRAuth *auth1 = [FIRAuth authWithApp:app1];
  XCTAssertNotNil(auth1);
  XCTAssertEqual(auth1.app, app1);

  FIRApp *app2 = [self app2];
  FIRAuth *auth2 = [FIRAuth authWithApp:app2];
  XCTAssertNotNil(auth2);
  XCTAssertEqual(auth2.app, app2);

  XCTAssertNotEqual(auth1, auth2);
}

/** @fn testLifeCycle
    @brief Verifies the life cycle of @c FIRAuth is the same as its associated @c FIRApp .
 */
- (void)testLifeCycle {
  __weak FIRApp *app;
  __weak FIRAuth *auth;
  @autoreleasepool {
    FIRApp *app1 = [self app1];
    app = app1;
    auth = [FIRAuth authWithApp:app1];
    // Verify that neither the app nor the auth is released yet, i.e., the app owns the auth
    // because nothing else retains the auth.
    XCTAssertNotNil(app);
    XCTAssertNotNil(auth);
  }
  [self waitForTimeIntervel:kWaitInterval];
  // Verify that both the app and the auth are released upon exit of the autorelease pool,
  // i.e., the app is the sole owner of the auth.
  XCTAssertNil(app);
  XCTAssertNil(auth);
}

/** @fn testGetUID
    @brief Verifies that FIRApp's getUIDImplementation is correctly set by FIRAuth.
 */
- (void)testGetUID {
  FIRApp *app = [FIRApp defaultApp];
  XCTAssertNotNil(app.getUIDImplementation);
  [[FIRAuth auth] signOut:NULL];
  XCTAssertNil(app.getUIDImplementation());
  [self waitForSignIn];
  XCTAssertEqualObjects(app.getUIDImplementation(), kLocalID);
}

#pragma mark - Server API Tests

/** @fn testFetchProvidersForEmailSuccess
    @brief Tests the flow of a successful @c fetchProvidersForEmail:completion: call.
 */
- (void)testFetchProvidersForEmailSuccess {
  NSArray<NSString *> *allProviders =
      @[ FIRGoogleAuthProviderID, FIREmailAuthProviderID ];
  OCMExpect([_mockBackend createAuthURI:[OCMArg any]
                               callback:[OCMArg any]])
      .andCallBlock2(^(FIRCreateAuthURIRequest *_Nullable request,
                       FIRCreateAuthURIResponseCallback callback) {
    XCTAssertEqualObjects(request.identifier, kEmail);
    XCTAssertNotNil(request.endpoint);
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockCreateAuthURIResponse = OCMClassMock([FIRCreateAuthURIResponse class]);
      OCMStub([mockCreateAuthURIResponse allProviders]).andReturn(allProviders);
      callback(mockCreateAuthURIResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] fetchProvidersForEmail:kEmail
                              completion:^(NSArray<NSString *> *_Nullable providers,
                                           NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqualObjects(providers, allProviders);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testFetchProvidersForEmailSuccessDeprecatedProviderID
    @brief Tests the flow of a successful @c fetchProvidersForEmail:completion: call using the
        deprecated FIREmailPasswordAuthProviderID.
 */
- (void)testFetchProvidersForEmailSuccessDeprecatedProviderID {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSArray<NSString *> *allProviders =
      @[ FIRGoogleAuthProviderID, FIREmailPasswordAuthProviderID ];
#pragma clang diagnostic pop
  OCMExpect([_mockBackend createAuthURI:[OCMArg any]
                               callback:[OCMArg any]])
      .andCallBlock2(^(FIRCreateAuthURIRequest *_Nullable request,
                       FIRCreateAuthURIResponseCallback callback) {
    XCTAssertEqualObjects(request.identifier, kEmail);
    XCTAssertNotNil(request.endpoint);
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockCreateAuthURIResponse = OCMClassMock([FIRCreateAuthURIResponse class]);
      OCMStub([mockCreateAuthURIResponse allProviders]).andReturn(allProviders);
      callback(mockCreateAuthURIResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] fetchProvidersForEmail:kEmail
                              completion:^(NSArray<NSString *> *_Nullable providers,
                                           NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqualObjects(providers, allProviders);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testFetchProvidersForEmailFailure
    @brief Tests the flow of a failed @c fetchProvidersForEmail:completion: call.
 */
- (void)testFetchProvidersForEmailFailure {
  OCMExpect([_mockBackend createAuthURI:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils tooManyRequestsErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] fetchProvidersForEmail:kEmail
                              completion:^(NSArray<NSString *> *_Nullable providers,
                                           NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(providers);
    XCTAssertEqual(error.code, FIRAuthErrorCodeTooManyRequests);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testPhoneAuthSuccess
    @brief Tests the flow of a successful @c signInWithCredential:completion for phone auth.
 */
- (void)testPhoneAuthSuccess {
  OCMExpect([_mockBackend verifyPhoneNumber:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPhoneNumberRequest *_Nullable request,
                       FIRVerifyPhoneNumberResponseCallback callback) {
    XCTAssertEqualObjects(request.verificationCode, kVerificationCode);
    XCTAssertEqualObjects(request.verificationID, kVerificationID);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVerifyPhoneResponse = OCMClassMock([FIRVerifyPhoneNumberResponse class]);
      [self stubTokensWithMockResponse:mockVerifyPhoneResponse];
      callback(mockVerifyPhoneResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                   verificationCode:kVerificationCode];

  [[FIRAuth auth] signInWithCredential:credential completion:^(FIRUser *_Nullable user,
                                                               NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUser:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testPhoneAuthMissingVerificationCode
    @brief Tests the flow of an unsuccessful @c signInWithCredential:completion for phone auth due
        to an empty verification code
 */
- (void)testPhoneAuthMissingVerificationCode {
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                   verificationCode:@""];

  [[FIRAuth auth] signInWithCredential:credential completion:^(FIRUser *_Nullable user,
                                                               NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeMissingVerificationCode);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testPhoneAuthMissingVerificationID
    @brief Tests the flow of an unsuccessful @c signInWithCredential:completion for phone auth due
        to an empty verification ID.
 */
- (void)testPhoneAuthMissingVerificationID {
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:@""
                                                   verificationCode:kVerificationCode];

  [[FIRAuth auth] signInWithCredential:credential completion:^(FIRUser *_Nullable user,
                                                               NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeMissingVerificationID);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testSignInWithEmailPasswordSuccess
    @brief Tests the flow of a successful @c signInWithEmail:password:completion: call.
 */
- (void)testSignInWithEmailPasswordSuccess {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                       FIRVerifyPasswordResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.email, kEmail);
    XCTAssertEqualObjects(request.password, kPassword);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVerifyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
      [self stubTokensWithMockResponse:mockVerifyPasswordResponse];
      callback(mockVerifyPasswordResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInWithEmail:kEmail password:kPassword completion:^(FIRUser *_Nullable user,
                                                                         NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUser:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithEmailPasswordFailure
    @brief Tests the flow of a failed @c signInWithEmail:password:completion: call.
 */
- (void)testSignInWithEmailPasswordFailure {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils wrongPasswordErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInWithEmail:kEmail password:kPassword completion:^(FIRUser *_Nullable user,
                                                                         NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeWrongPassword);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testResetPasswordSuccess
    @brief Tests the flow of a successful @c confirmPasswordResetWithCode:newPassword:completion:
        call.
 */
- (void)testResetPasswordSuccess {
  NSString *fakeEmail = @"fakeEmail";
  NSString *fakeCode = @"fakeCode";
  NSString *fakeNewPassword = @"fakeNewPassword";
  OCMExpect([_mockBackend resetPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRResetPasswordRequest *_Nullable request,
                       FIRResetPasswordCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.oobCode, fakeCode);
    XCTAssertEqualObjects(request.updatedPassword, fakeNewPassword);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockResetPasswordResponse = OCMClassMock([FIRResetPasswordResponse class]);
      OCMStub([mockResetPasswordResponse email]).andReturn(fakeEmail);
      callback(mockResetPasswordResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] confirmPasswordResetWithCode:fakeCode
                                   newPassword:fakeNewPassword
                                    completion:^(NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testResetPasswordFailure
    @brief Tests the flow of a failed @c confirmPasswordResetWithCode:newPassword:completion:
        call.
 */
- (void)testResetPasswordFailure {
  NSString *fakeCode = @"fakeCode";
  NSString *fakeNewPassword = @"fakeNewPassword";
  OCMExpect([_mockBackend resetPassword:[OCMArg any] callback:[OCMArg any]])
      ._andDispatchError2([FIRAuthErrorUtils invalidActionCodeErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] confirmPasswordResetWithCode:fakeCode
                                   newPassword:fakeNewPassword
                                    completion:^(NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidActionCode);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testCheckActionCodeSuccess
    @brief Tests the flow of a successful @c checkActionCode:completion call.
 */
- (void)testCheckActionCodeSuccess {
  NSString *verifyEmailRequestType = @"VERIFY_EMAIL";
  NSString *fakeEmail = @"fakeEmail";
  NSString *fakeNewEmail = @"fakeNewEmail";
  NSString *fakeCode = @"fakeCode";
  OCMExpect([_mockBackend resetPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRResetPasswordRequest *_Nullable request,
                       FIRResetPasswordCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.oobCode, fakeCode);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockResetPasswordResponse = OCMClassMock([FIRResetPasswordResponse class]);
      OCMStub([mockResetPasswordResponse email]).andReturn(fakeEmail);
      OCMStub([mockResetPasswordResponse verifiedEmail]).andReturn(fakeNewEmail);
      OCMStubRecorder *stub =
          OCMStub([(FIRResetPasswordResponse *) mockResetPasswordResponse requestType]);
      stub.andReturn(verifyEmailRequestType);
      callback(mockResetPasswordResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] checkActionCode:fakeCode completion:^(FIRActionCodeInfo *_Nullable info,
                                                        NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    XCTAssertEqual(info.operation, FIRActionCodeOperationVerifyEmail);
    XCTAssert([fakeNewEmail isEqualToString:[info dataForKey:FIRActionCodeEmailKey]]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testCheckActionCodeFailure
    @brief Tests the flow of a failed @c checkActionCode:completion call.
 */
- (void)testCheckActionCodeFailure {
  NSString *fakeCode = @"fakeCode";
  OCMExpect([_mockBackend resetPassword:[OCMArg any] callback:[OCMArg any]])
      ._andDispatchError2([FIRAuthErrorUtils expiredActionCodeErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] checkActionCode:fakeCode completion:^(FIRActionCodeInfo *_Nullable info,
                                                        NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRAuthErrorCodeExpiredActionCode);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testApplyActionCodeSuccess
    @brief Tests the flow of a successful @c applyActionCode:completion call.
 */
- (void)testApplyActionCodeSuccess {
  NSString *fakeCode = @"fakeCode";
  OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                       FIRSetAccountInfoResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.OOBCode, fakeCode);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
      callback(mockSetAccountInfoResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] applyActionCode:fakeCode completion:^(NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testApplyActionCodeFailure
    @brief Tests the flow of a failed @c checkActionCode:completion call.
 */
- (void)testApplyActionCodeFailure {
  NSString *fakeCode = @"fakeCode";
  OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
      ._andDispatchError2([FIRAuthErrorUtils invalidActionCodeErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] applyActionCode:fakeCode completion:^(NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidActionCode);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testVerifyPasswordResetCodeSuccess
    @brief Tests the flow of a successful @c verifyPasswordResetCode:completion call.
 */
- (void)testVerifyPasswordResetCodeSuccess {
  NSString *passwordResetRequestType = @"PASSWORD_RESET";
  NSString *fakeEmail = @"fakeEmail";
  NSString *fakeCode = @"fakeCode";
  OCMExpect([_mockBackend resetPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRResetPasswordRequest *_Nullable request,
                       FIRResetPasswordCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.oobCode, fakeCode);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockResetPasswordResponse = OCMClassMock([FIRResetPasswordResponse class]);
      OCMStub([mockResetPasswordResponse email]).andReturn(fakeEmail);
      OCMStubRecorder *stub =
          OCMStub([(FIRResetPasswordResponse *) mockResetPasswordResponse requestType]);
      stub.andReturn(passwordResetRequestType);
      callback(mockResetPasswordResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] verifyPasswordResetCode:fakeCode completion:^(NSString *_Nullable email,
                                                                NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    XCTAssertEqual(email, fakeEmail);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testVerifyPasswordResetCodeFailure
    @brief Tests the flow of a failed @c verifyPasswordResetCode:completion call.
 */
- (void)testVeridyPasswordResetCodeFailure {
  NSString *fakeCode = @"fakeCode";
  OCMExpect([_mockBackend resetPassword:[OCMArg any] callback:[OCMArg any]])
      ._andDispatchError2([FIRAuthErrorUtils invalidActionCodeErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] verifyPasswordResetCode:fakeCode completion:^(NSString *_Nullable email,
                                                                NSError *_Nullable error) {

    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidActionCode);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithEmailCredentialSuccess
    @brief Tests the flow of a successfully @c signInWithCredential:completion: call with an
        email-password credential.
 */
- (void)testSignInWithEmailCredentialSuccess {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                       FIRVerifyPasswordResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.email, kEmail);
    XCTAssertEqualObjects(request.password, kPassword);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
      [self stubTokensWithMockResponse:mockVeriyPasswordResponse];
      callback(mockVeriyPasswordResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *emailCredential =
      [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
  [[FIRAuth auth] signInWithCredential:emailCredential completion:^(FIRUser *_Nullable user,
                                                                    NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUser:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithEmailCredentialSuccess
    @brief Tests the flow of a successfully @c signInWithCredential:completion: call with an
        email-password credential using the deprecated FIREmailPasswordAuthProvider.
 */
- (void)testSignInWithEmailCredentialSuccessWithDepricatedProvider {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                       FIRVerifyPasswordResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.email, kEmail);
    XCTAssertEqualObjects(request.password, kPassword);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
      [self stubTokensWithMockResponse:mockVeriyPasswordResponse];
      callback(mockVeriyPasswordResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  FIRAuthCredential *emailCredential =
      [FIREmailPasswordAuthProvider credentialWithEmail:kEmail password:kPassword];
#pragma clang diagnostic pop
  [[FIRAuth auth] signInWithCredential:emailCredential completion:^(FIRUser *_Nullable user,
                                                                    NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUser:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithEmailCredentialFailure
    @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
        email-password credential.
 */
- (void)testSignInWithEmailCredentialFailure {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils userDisabledErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *emailCredential =
      [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
  [[FIRAuth auth] signInWithCredential:emailCredential completion:^(FIRUser *_Nullable user,
                                                                    NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeUserDisabled);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithEmailCredentialEmptyPassword
    @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
        email-password credential using an empty password. This error occurs on the client side,
        so there is no need to fake an RPC response.
 */
- (void)testSignInWithEmailCredentialEmptyPassword {
  NSString *emptyString = @"";
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *emailCredential =
      [FIREmailAuthProvider credentialWithEmail:kEmail password:emptyString];
  [[FIRAuth auth] signInWithCredential:emailCredential completion:^(FIRUser *_Nullable user,
                                                                    NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(error.code, FIRAuthErrorCodeWrongPassword);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testSignInWithGoogleAccountExistsError
    @brief Tests the flow of a failed @c signInWithCredential:completion: with a Google credential
        where the backend returns a needs @needConfirmation equal to true. An
        FIRAuthErrorCodeAccountExistsWithDifferentCredential error should be thrown.
 */
- (void)testSignInWithGoogleAccountExistsError {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProviderID);
    XCTAssertEqualObjects(request.providerIDToken, kGoogleIDToken);
    XCTAssertEqualObjects(request.providerAccessToken, kGoogleAccessToken);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
      OCMStub([mockVeriyAssertionResponse needConfirmation]).andReturn(YES);
      OCMStub([mockVeriyAssertionResponse email]).andReturn(kEmail);
      [self stubTokensWithMockResponse:mockVeriyAssertionResponse];
      callback(mockVeriyAssertionResponse, nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth] signInWithCredential:googleCredential completion:^(FIRUser *_Nullable user,
                                                                     NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(error.code, FIRAuthErrorCodeAccountExistsWithDifferentCredential);
    XCTAssertEqualObjects(error.userInfo[FIRAuthErrorUserInfoEmailKey], kEmail);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithGoogleCredentialSuccess
    @brief Tests the flow of a successful @c signInWithCredential:completion: call with an
        Google Sign-In credential.
 */
- (void)testSignInWithGoogleCredentialSuccess {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProviderID);
    XCTAssertEqualObjects(request.providerIDToken, kGoogleIDToken);
    XCTAssertEqualObjects(request.providerAccessToken, kGoogleAccessToken);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
      OCMStub([mockVeriyAssertionResponse federatedID]).andReturn(kGoogleID);
      OCMStub([mockVeriyAssertionResponse providerID]).andReturn(FIRGoogleAuthProviderID);
      OCMStub([mockVeriyAssertionResponse localID]).andReturn(kLocalID);
      OCMStub([mockVeriyAssertionResponse displayName]).andReturn(kGoogleDisplayName);
      [self stubTokensWithMockResponse:mockVeriyAssertionResponse];
      callback(mockVeriyAssertionResponse, nil);
    });
  });
  [self expectGetAccountInfoGoogle];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth] signInWithCredential:googleCredential completion:^(FIRUser *_Nullable user,
                                                                     NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserGoogle:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInAndRetrieveDataWithCredentialSuccess
    @brief Tests the flow of a successful @c signInAndRetrieveDataWithCredential:completion: call
        with an Google Sign-In credential.
 */
- (void)testSignInAndRetrieveDataWithCredentialSuccess {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProviderID);
    XCTAssertEqualObjects(request.providerIDToken, kGoogleIDToken);
    XCTAssertEqualObjects(request.providerAccessToken, kGoogleAccessToken);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
      OCMStub([mockVeriyAssertionResponse federatedID]).andReturn(kGoogleID);
      OCMStub([mockVeriyAssertionResponse providerID]).andReturn(FIRGoogleAuthProviderID);
      OCMStub([mockVeriyAssertionResponse localID]).andReturn(kLocalID);
      OCMStub([mockVeriyAssertionResponse displayName]).andReturn(kGoogleDisplayName);
      OCMStub([mockVeriyAssertionResponse profile]).andReturn([[self class] googleProfile]);
      OCMStub([mockVeriyAssertionResponse username]).andReturn(kDisplayName);
      [self stubTokensWithMockResponse:mockVeriyAssertionResponse];
      callback(mockVeriyAssertionResponse, nil);
    });
  });
  [self expectGetAccountInfoGoogle];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:googleCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserGoogle:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kDisplayName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRGoogleAuthProviderID);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithGoogleCredentialFailure
    @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
        Google Sign-In credential.
 */
- (void)testSignInWithGoogleCredentialFailure {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils emailAlreadyInUseErrorWithEmail:kGoogleEmail]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth] signInWithCredential:googleCredential  completion:^(FIRUser *_Nullable user,
                                                                      NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeEmailAlreadyInUse);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInAnonymouslySuccess
    @brief Tests the flow of a successful @c signInAnonymously:completion: call.
 */
- (void)testSignInAnonymouslySuccess {
  OCMExpect([_mockBackend signUpNewUser:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSignUpNewUserRequest *_Nullable request,
                       FIRSignupNewUserCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertNil(request.email);
    XCTAssertNil(request.password);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSignUpNewUserResponse = OCMClassMock([FIRSignUpNewUserResponse class]);
      [self stubTokensWithMockResponse:mockSignUpNewUserResponse];
      callback(mockSignUpNewUserResponse, nil);
    });
  });
  [self expectGetAccountInfoAnonymous];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInAnonymouslyWithCompletion:^(FIRUser *_Nullable user,
                                                    NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserAnonymous:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserAnonymous:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInAnonymouslyFailure
    @brief Tests the flow of a failed @c signInAnonymously:completion: call.
 */
- (void)testSignInAnonymouslyFailure {
  OCMExpect([_mockBackend signUpNewUser:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils operationNotAllowedErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInAnonymouslyWithCompletion:^(FIRUser *_Nullable user,
                                                    NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeOperationNotAllowed);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithCustomTokenSuccess
    @brief Tests the flow of a successful @c signInWithCustomToken:completion: call.
 */
- (void)testSignInWithCustomTokenSuccess {
  OCMExpect([_mockBackend verifyCustomToken:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyCustomTokenRequest *_Nullable request,
                       FIRVerifyCustomTokenResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.token, kCustomToken);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyCustomTokenResponse = OCMClassMock([FIRVerifyCustomTokenResponse class]);
      [self stubTokensWithMockResponse:mockVeriyCustomTokenResponse];
      callback(mockVeriyCustomTokenResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInWithCustomToken:kCustomToken completion:^(FIRUser *_Nullable user,
                                                                  NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUser:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithCustomTokenFailure
    @brief Tests the flow of a failed @c signInWithCustomToken:completion: call.
 */
- (void)testSignInWithCustomTokenFailure {
  OCMExpect([_mockBackend verifyCustomToken:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils invalidCustomTokenErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInWithCustomToken:kCustomToken completion:^(FIRUser *_Nullable user,
                                                                  NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidCustomToken);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testCreateUserWithEmailPasswordSuccess
    @brief Tests the flow of a successful @c createUserWithEmail:password:completion: call.
 */
- (void)testCreateUserWithEmailPasswordSuccess {
  OCMExpect([_mockBackend signUpNewUser:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSignUpNewUserRequest *_Nullable request,
                       FIRSignupNewUserCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.email, kEmail);
    XCTAssertEqualObjects(request.password, kPassword);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSignUpNewUserResponse = OCMClassMock([FIRSignUpNewUserResponse class]);
      [self stubTokensWithMockResponse:mockSignUpNewUserResponse];
      callback(mockSignUpNewUserResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] createUserWithEmail:kEmail
                             password:kPassword
                           completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUser:user];
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testCreateUserWithEmailPasswordFailure
    @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call.
 */
- (void)testCreateUserWithEmailPasswordFailure {
  NSString *reason = @"Password shouldn't be a common word.";
  OCMExpect([_mockBackend signUpNewUser:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils weakPasswordErrorWithServerResponseReason:reason]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] createUserWithEmail:kEmail
                             password:kPassword
                           completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(user);
    XCTAssertEqual(error.code, FIRAuthErrorCodeWeakPassword);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    XCTAssertEqualObjects(error.userInfo[NSLocalizedFailureReasonErrorKey], reason);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testCreateUserEmptyPasswordFailure
    @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call due to an
        empty password. This error occurs on the client side, so there is no need to fake an RPC
        response.
 */
- (void)testCreateUserEmptyPasswordFailure {
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] createUserWithEmail:kEmail
                             password:@""
                           completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(error.code, FIRAuthErrorCodeWeakPassword);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testSendPasswordResetEmailSuccess
    @brief Tests the flow of a successful @c sendPasswordResetWithEmail:completion: call.
 */
- (void)testSendPasswordResetEmailSuccess {
  OCMExpect([_mockBackend getOOBConfirmationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetOOBConfirmationCodeRequest *_Nullable request,
                       FIRGetOOBConfirmationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.email, kEmail);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback([[FIRGetOOBConfirmationCodeResponse alloc] init], nil);
    });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] sendPasswordResetWithEmail:kEmail completion:^(NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSendPasswordResetEmailFailure
    @brief Tests the flow of a failed @c sendPasswordResetWithEmail:completion: call.
 */
- (void)testSendPasswordResetEmailFailure {
  OCMExpect([_mockBackend getOOBConfirmationCode:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils appNotAuthorizedError]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] sendPasswordResetWithEmail:kEmail completion:^(NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(error.code, FIRAuthErrorCodeAppNotAuthorized);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignOut
    @brief Tests the @c signOut: method.
 */
- (void)testSignOut {
  [self waitForSignIn];
  // Verify signing out succeeds and clears the current user.
  NSError *error;
  XCTAssertTrue([[FIRAuth auth] signOut:&error]);
  XCTAssertNil([FIRAuth auth].currentUser);
}

/** @fn testAuthStateChanges
    @brief Tests @c addAuthStateDidChangeListener: and @c removeAuthStateDidChangeListener: methods.
 */
- (void)testAuthStateChanges {
  // Set up listener.
  __block XCTestExpectation *expectation;
  __block BOOL shouldHaveUser;
  FIRAuthStateDidChangeListenerBlock listener = ^(FIRAuth *auth, FIRUser *_Nullable user) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(auth, [FIRAuth auth]);
    XCTAssertEqual(user, [FIRAuth auth].currentUser);
    if (shouldHaveUser) {
      XCTAssertNotNil(user);
    } else {
      XCTAssertNil(user);
    }
    // `expectation` being nil means the listener is not expected to be fired at this moment.
    XCTAssertNotNil(expectation);
    [expectation fulfill];
  };
  [[FIRAuth auth] signOut:NULL];
  [self waitForTimeIntervel:kWaitInterval];  // Wait until dust settled from previous tests.

  // Listener should fire immediately when attached.
  expectation = [self expectationWithDescription:@"initial"];
  shouldHaveUser = NO;
  FIRAuthStateDidChangeListenerHandle handle =
      [[FIRAuth auth] addAuthStateDidChangeListener:listener];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Listener should fire for signing in.
  expectation = [self expectationWithDescription:@"sign-in"];
  shouldHaveUser = YES;
  [self waitForSignIn];

  // Listener should not fire for signing in again.
  shouldHaveUser = YES;
  [self waitForSignIn];
  [self waitForTimeIntervel:kWaitInterval];  // make sure listener is not called

  // Listener should fire for signing out.
  expectation = [self expectationWithDescription:@"sign-out"];
  shouldHaveUser = NO;
  [[FIRAuth auth] signOut:NULL];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Listener should no longer fire once detached.
  expectation = nil;
  [[FIRAuth auth] removeAuthStateDidChangeListener:handle];
  [self waitForSignIn];
  [self waitForTimeIntervel:kWaitInterval];  // make sure listener is no longer called
}

/** @fn testIDTokenChanges
    @brief Tests @c addIDTokenDidChangeListener: and @c removeIDTokenDidChangeListener: methods.
 */
- (void)testIDTokenChanges {
  // Set up listener.
  __block XCTestExpectation *expectation;
  __block BOOL shouldHaveUser;
  FIRIDTokenDidChangeListenerBlock listener = ^(FIRAuth *auth, FIRUser *_Nullable user) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertEqual(auth, [FIRAuth auth]);
    XCTAssertEqual(user, [FIRAuth auth].currentUser);
    if (shouldHaveUser) {
      XCTAssertNotNil(user);
    } else {
      XCTAssertNil(user);
    }
    // `expectation` being nil means the listener is not expected to be fired at this moment.
    XCTAssertNotNil(expectation);
    [expectation fulfill];
  };
  [[FIRAuth auth] signOut:NULL];
  [self waitForTimeIntervel:kWaitInterval];  // Wait until dust settled from previous tests.

  // Listener should fire immediately when attached.
  expectation = [self expectationWithDescription:@"initial"];
  shouldHaveUser = NO;
  FIRIDTokenDidChangeListenerHandle handle =
      [[FIRAuth auth] addIDTokenDidChangeListener:listener];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Listener should fire for signing in.
  expectation = [self expectationWithDescription:@"sign-in"];
  shouldHaveUser = YES;
  [self waitForSignIn];

  // Listener should fire for signing in again as the same user.
  expectation = [self expectationWithDescription:@"sign-in again"];
  shouldHaveUser = YES;
  [self waitForSignIn];

  // Listener should fire for signing out.
  expectation = [self expectationWithDescription:@"sign-out"];
  shouldHaveUser = NO;
  [[FIRAuth auth] signOut:NULL];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Listener should no longer fire once detached.
  expectation = nil;
  [[FIRAuth auth] removeIDTokenDidChangeListener:handle];
  [self waitForSignIn];
  [self waitForTimeIntervel:kWaitInterval];  // make sure listener is no longer called
}

#pragma mark - Automatic Token Refresh Tests.

/** @fn testAutomaticTokenRefresh
    @brief Tests a successful flow to automatically refresh tokens for a signed in user.
 */
- (void)testAutomaticTokenRefresh {
  [[FIRAuth auth] signOut:NULL];

  // Enable auto refresh
  [self enableAutoTokenRefresh];

  // Sign in a user.
  [self waitForSignIn];

  // Set up expectation for secureToken RPC made by token refresh task.
  [self mockSecureTokenResponseWithError:nil];

  // Verify that the current user's access token is the "old" access token before automatic token
  // refresh.
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(_FIRAuthDispatcherCallback);
    _FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Verify that current user's access token is the "new" access token provided in the mock secure
  // token response during automatic token refresh.
  XCTAssertEqualObjects(kNewAccessToken, [FIRAuth auth].currentUser.rawAccessToken);
  OCMVerifyAll(_mockBackend);
}

/** @fn testAutomaticTokenRefreshInvalidTokenFailure
    @brief Tests an unsuccessful flow to auto refresh tokens with an "invalid token" error.
        This error should cause the user to be signed out.
 */
- (void)testAutomaticTokenRefreshInvalidTokenFailure {
  [[FIRAuth auth] signOut:NULL];
  // Enable auto refresh
  [self enableAutoTokenRefresh];

  // Sign in a user.
  [self waitForSignIn];

  // Set up expectation for secureToken RPC made by a failed attempt to refresh tokens.
  [self mockSecureTokenResponseWithError:[FIRAuthErrorUtils invalidUserTokenErrorWithMessage:nil]];

  // Verify that current user is still valid.
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(_FIRAuthDispatcherCallback);
    _FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  //Verify that the user is nil after failed attempt to refresh tokens caused signed out.
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

/** @fn testAutomaticTokenRefreshRetry
    @brief Tests that a retry is attempted for a automatic token refresh task (which is not due to
        invalid tokens). The initial attempt to refresh the access token fails, but the second
        attempt is successful.
 */
- (void)testAutomaticTokenRefreshRetry {
  [[FIRAuth auth] signOut:NULL];
  // Enable auto refresh
  [self enableAutoTokenRefresh];

  // Sign in a user.
  [self waitForSignIn];

  // Set up expectation for secureToken RPC made by a failed attempt to refresh tokens.
  [self mockSecureTokenResponseWithError:[NSError errorWithDomain:@"ERROR" code:-1 userInfo:nil]];

  // Execute saved token refresh task.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(_FIRAuthDispatcherCallback);
    _FIRAuthDispatcherCallback();
    _FIRAuthDispatcherCallback = nil;
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // The old access token should still be the current user's access token and not the new access
  // token (kNewAccessToken).
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Set up expectation for secureToken RPC made by a successful attempt to refresh tokens.
  [self mockSecureTokenResponseWithError:nil];

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(_FIRAuthDispatcherCallback);
    _FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Verify that current user's access token is the "new" access token provided in the mock secure
  // token response during automatic token refresh.
  XCTAssertEqualObjects([FIRAuth auth].currentUser.rawAccessToken, kNewAccessToken);
  OCMVerifyAll(_mockBackend);
}

/** @fn testAutomaticTokenRefreshInvalidTokenFailure
    @brief Tests that app foreground notification triggers the scheduling of an automatic token
        refresh task.
 */
- (void)testAutoRefreshAppForegroundedNotification {
  [[FIRAuth auth] signOut:NULL];
  // Enable auto refresh
  [self enableAutoTokenRefresh];

  // Sign in a user.
  [self waitForSignIn];

  // Post "UIApplicationDidBecomeActiveNotification" to trigger scheduling token refresh task.
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];

  // Verify that current user is still valid with old access token.
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Set up expectation for secureToken RPC made by a successful attempt to refresh tokens.
  [self mockSecureTokenResponseWithError:nil];

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(_FIRAuthDispatcherCallback);
    _FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  // Verify that current user is still valid with new access token.
  XCTAssertEqualObjects(kNewAccessToken, [FIRAuth auth].currentUser.rawAccessToken);
  OCMVerifyAll(_mockBackend);
}

#pragma mark - Helpers

/** @fn mockSecureTokenResponseWithError:
    @brief Set up expectation for secureToken RPC.
    @param error The error that the mock should return if any.
 */
- (void)mockSecureTokenResponseWithError:(nullable NSError *)error {
  // Set up expectation for secureToken RPC made by a successful attempt to refresh tokens.
  XCTestExpectation *secureTokenResponseExpectation =
      [self expectationWithDescription:@"secureTokenResponseExpectation"];
  OCMExpect([_mockBackend secureToken:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSecureTokenRequest *_Nullable request,
                       FIRSecureTokenResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.refreshToken, kRefreshToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      if (error) {
        callback(nil, error);
        [secureTokenResponseExpectation fulfill];
        return;
      }
      id mockSecureTokenResponse = OCMClassMock([FIRSecureTokenResponse class]);
      OCMStub([mockSecureTokenResponse accessToken]).andReturn(kNewAccessToken);
      NSDate *futureDate =
          [[NSDate date] dateByAddingTimeInterval:kTestTokenExpirationTimeInterval];
      OCMStub([mockSecureTokenResponse approximateExpirationDate]).andReturn(futureDate);
      callback(mockSecureTokenResponse, nil);
      [secureTokenResponseExpectation fulfill];
    });
  });
}

/** @fn enableAutoTokenRefresh
    @brief Enables automatic token refresh by invoking FIRAuth's implementation of FIRApp's
        |getTokenWithImplementation|.
 */
- (void)enableAutoTokenRefresh {
  XCTestExpectation *expectation = [self expectationWithDescription:@"autoTokenRefreshcallback"];
  [[FIRAuth auth].app getTokenForcingRefresh:NO withCallback:^(NSString *_Nullable token,
                                                                NSError *_Nullable error) {
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn app1
    @brief Creates a Firebase app.
    @return A @c FIRApp with some name.
 */
- (FIRApp *)app1 {
  return [FIRApp appForAuthUnitTestsWithName:kFirebaseAppName1];
}

/** @fn app2
    @brief Creates another Firebase app.
    @return A @c FIRApp with some other name.
 */
- (FIRApp *)app2 {
  return [FIRApp appForAuthUnitTestsWithName:kFirebaseAppName2];
}

/** @fn stubSecureTokensWithMockResponse
    @brief Creates stubs on the mock response object with access and refresh tokens
    @param mockResponse The mock response object.
 */
- (void)stubTokensWithMockResponse:(id)mockResponse {
  OCMStub([mockResponse IDToken]).andReturn(kAccessToken);
  OCMStub([mockResponse approximateExpirationDate])
      .andReturn([NSDate dateWithTimeIntervalSinceNow:kAccessTokenTimeToLive]);
  OCMStub([mockResponse refreshToken]).andReturn(kRefreshToken);
}

/** @fn expectGetAccountInfo
    @brief Expects a GetAccountInfo request on the mock backend and calls back with fake account
        data.
 */
- (void)expectGetAccountInfo {
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.accessToken, kAccessToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
      OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
      OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kDisplayName);
      OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
      OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
      id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
      OCMStub([mockGetAccountInfoResponse users]).andReturn(@[ mockGetAccountInfoResponseUser ]);
      callback(mockGetAccountInfoResponse, nil);
    });
  });
}

/** @fn assertUser
    @brief Asserts the given FIRUser matching the fake data returned by @c expectGetAccountInfo.
    @param user The user object to be verified.
 */
- (void)assertUser:(FIRUser *)user {
  XCTAssertNotNil(user);
  XCTAssertEqualObjects(user.uid, kLocalID);
  XCTAssertEqualObjects(user.displayName, kDisplayName);
  XCTAssertEqualObjects(user.email, kEmail);
  XCTAssertFalse(user.anonymous);
  XCTAssertEqual(user.providerData.count, 0u);
}

/** @fn expectGetAccountInfoGoogle
    @brief Expects a GetAccountInfo request on the mock backend and calls back with fake account
        data for a Google Sign-In user.
 */
- (void)expectGetAccountInfoGoogle {
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.accessToken, kAccessToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockGoogleUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
      OCMStub([mockGoogleUserInfo providerID]).andReturn(FIRGoogleAuthProviderID);
      OCMStub([mockGoogleUserInfo displayName]).andReturn(kGoogleDisplayName);
      OCMStub([mockGoogleUserInfo federatedID]).andReturn(kGoogleID);
      OCMStub([mockGoogleUserInfo email]).andReturn(kGoogleEmail);
      id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
      OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
      OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kDisplayName);
      OCMStub([mockGetAccountInfoResponseUser providerUserInfo])
          .andReturn((@[ mockGoogleUserInfo ]));
      id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
      OCMStub([mockGetAccountInfoResponse users]).andReturn(@[ mockGetAccountInfoResponseUser ]);
      callback(mockGetAccountInfoResponse, nil);
    });
  });
}

/** @fn assertUserGoogle
    @brief Asserts the given FIRUser matching the fake data returned by
        @c expectGetAccountInfoGoogle.
    @param user The user object to be verified.
 */
- (void)assertUserGoogle:(FIRUser *)user {
  XCTAssertNotNil(user);
  XCTAssertEqualObjects(user.uid, kLocalID);
  XCTAssertEqualObjects(user.displayName, kDisplayName);
  XCTAssertEqual(user.providerData.count, 1u);
  id<FIRUserInfo> googleUserInfo = user.providerData[0];
  XCTAssertEqualObjects(googleUserInfo.providerID, FIRGoogleAuthProviderID);
  XCTAssertEqualObjects(googleUserInfo.uid, kGoogleID);
  XCTAssertEqualObjects(googleUserInfo.displayName, kGoogleDisplayName);
  XCTAssertEqualObjects(googleUserInfo.email, kGoogleEmail);
}

/** @fn expectGetAccountInfoAnonymous
    @brief Expects a GetAccountInfo request on the mock backend and calls back with fake anonymous
        account data.
 */
- (void)expectGetAccountInfoAnonymous {
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.accessToken, kAccessToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
      OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
      id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
      OCMStub([mockGetAccountInfoResponse users]).andReturn(@[ mockGetAccountInfoResponseUser ]);
      callback(mockGetAccountInfoResponse, nil);
    });
  });
}

/** @fn assertUserAnonymous
    @brief Asserts the given FIRUser matching the fake data returned by
        @c expectGetAccountInfoAnonymous.
    @param user The user object to be verified.
 */
- (void)assertUserAnonymous:(FIRUser *)user {
  XCTAssertNotNil(user);
  XCTAssertEqualObjects(user.uid, kLocalID);
  XCTAssertNil(user.displayName);
  XCTAssertTrue(user.anonymous);
  XCTAssertEqual(user.providerData.count, 0u);
}

/** @fn waitForSignIn
    @brief Signs in a user to prepare for tests.
    @remarks This method also waits for all other pending @c XCTestExpectation instances.
 */
- (void)waitForSignIn {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                       FIRVerifyPasswordResponseCallback callback) {
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
      [self stubTokensWithMockResponse:mockVeriyPasswordResponse];
      callback(mockVeriyPasswordResponse, nil);
    });
  });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signInWithEmail:kEmail password:kPassword completion:^(FIRUser *_Nullable user,
                                                                         NSError *_Nullable error) {
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  XCTAssertNotNil([FIRAuth auth].currentUser);
}

/** @fn waitForTimeInterval:
    @brief Wait for a particular time interval.
    @remarks This method also waits for all other pending @c XCTestExpectation instances.
 */
- (void)waitForTimeIntervel:(NSTimeInterval)timeInterval {
  static dispatch_queue_t queue;
  static dispatch_once_t onceToken;
  XCTestExpectation *expectation = [self expectationWithDescription:@"waitForTimeIntervel:"];
  dispatch_once(&onceToken, ^{
    queue = dispatch_queue_create("com.google.FIRAuthUnitTests.waitForTimeIntervel", NULL);
  });
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeInterval * NSEC_PER_SEC), queue, ^() {
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:timeInterval + kExpectationTimeout handler:nil];
}

@end

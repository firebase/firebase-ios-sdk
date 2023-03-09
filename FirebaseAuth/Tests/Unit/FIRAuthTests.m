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
#ifdef TODO_SWIFT
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULAppDelegateSwizzler.h>
#import "FirebaseAuth/Interop/FIRAuthInterop.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthSettings.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseAuth/Sources/Auth/FIRAuthDispatcher.h"
#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
@import FirebaseAuth;
#import "FirebaseAuth/Sources/User/FIRUser_Internal.h"
#import "FirebaseAuth/Tests/Unit/FIRApp+FIRAuthUnitTests.h"

#if TARGET_OS_IOS
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthUIDelegate.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSTokenManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthNotificationManager.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthURLPresenter.h"
#endif  // TARGET_OS_IOS

/** @var kAPIKey
    @brief The fake API key.
 */
static NSString *const kAPIKey = @"FAKE_API_KEY";

/** @var kFirebaseAppID
    @brief The fake Firebase app ID.
 */
static NSString *const kFirebaseAppID = @"FAKE_APP_ID";

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

/** @var kFakePassword
    @brief The fake user password.
 */
static NSString *const kFakePassword = @"!@#$%^";

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
- (void)testSignInWithAppleCredentialFullNameInRequestSuccess {
  NSPersonNameComponents *fullName = [[NSPersonNameComponents alloc] init];
  fullName.givenName = kFakeGivenName;
  fullName.familyName = kFakeFamilyName;
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.providerID, kAppleAuthProviderID);
        XCTAssertEqualObjects(request.providerIDToken, kAppleIDToken);
        // Verify that the full name is passed to the backend request.
        XCTAssertEqualObjects(request.fullName, fullName);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse providerID]).andReturn(kAppleAuthProviderID);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.accessToken, kAccessToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockAppleUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
          OCMStub([mockAppleUserInfo providerID]).andReturn(kAppleAuthProviderID);
          id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
          OCMStub([mockGetAccountInfoResponseUser providerUserInfo])
              .andReturn((@[ mockAppleUserInfo ]));
          id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
          OCMStub([mockGetAccountInfoResponse users]).andReturn(@[
            mockGetAccountInfoResponseUser
          ]);
          callback(mockGetAccountInfoResponse, nil);
        });
      });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *appleCredential = [FIROAuthProvider appleCredentialWithIDToken:kAppleIDToken
                                                                           rawNonce:nil
                                                                           fullName:fullName];
  [[FIRAuth auth]
      signInWithCredential:appleCredential
                completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(error);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNotNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
static NSString *const kFakeFamilyName = @"Lastname";

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

/** @var kAppleAuthProviderID
    @brief The provider ID for Apple Sign-In.
 */
static NSString *const kAppleAuthProviderID = @"apple.com";

/** @var kAppleIDToken
    @brief The fake ID token from Apple Sign-In.
 */
static NSString *const kAppleIDToken = @"APPLE_ID_TOKEN";

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

/** @var kOAuthRequestURI
    @brief Fake OAuthRequest URI for testing.
 */
static NSString *const kOAuthRequestURI = @"requestURI";

/** @var kOAuthSessionID
    @brief Fake session ID for testing.
 */
static NSString *const kOAuthSessionID = @"sessionID";

/** @var kFakeWebSignInUserInteractionFailureReason
    @brief Fake reason for FIRAuthErrorCodeWebSignInUserInteractionFailure error while testing.
 */
static NSString *const kFakeWebSignInUserInteractionFailureReason = @"fake_reason";

/** @var kContinueURL
    @brief Fake string value of continue url.
 */
static NSString *const kContinueURL = @"continueURL";

/** @var kCanHandleCodeInAppKey
    @brief The key for the request parameter indicating whether the action code can be handled in
        the app or not.
 */
static NSString *const kCanHandleCodeInAppKey = @"canHandleCodeInApp";

/** @var kFIREmailLinkAuthSignInMethod
    @brief Fake email link sign-in method for testing.
 */
static NSString *const kFIREmailLinkAuthSignInMethod = @"emailLink";

/** @var kFIRFacebookAuthSignInMethod
    @brief Fake Facebook sign-in method for testing.
 */
static NSString *const kFIRFacebookAuthSignInMethod = @"facebook.com";

/** @var kBadSignInEmailLink
    @brief Bad sign-in link to test email link sign-in
 */
static NSString *const kBadSignInEmailLink = @"http://www.facebook.com";

/** @var kFakeEmailSignInDeeplink
    @brief Fake email sign-in link
 */
static NSString *const kFakeEmailSignInDeeplink =
    @"https://example.domain.com/?apiKey=testAPIKey&oobCode=testoobcode&mode=signIn";

/** @var kFakeEmailSignInlink
    @brief Fake email sign-in link
 */
static NSString *const kFakeEmailSignInlink =
    @"https://test.app.goo.gl/?link=https://test.firebase"
     "app.com/__/auth/"
     "action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueU"
     "rl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/"
     "action?ap"
     "iKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://"
     "test.apps.co"
     "m";

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 2;

/** @var kWaitInterval
    @brief The time waiting for background tasks to finish before continue when necessary.
 */
static const NSTimeInterval kWaitInterval = .5;

#if TARGET_OS_IOS
/** @class FIRAuthAppDelegate
    @brief Application delegate implementation to test the app delegate proxying
 */
@interface FIRAuthAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation FIRAuthAppDelegate
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  return NO;
}

@end

#endif  // TARGET_OS_IOS

@interface GULAppDelegateSwizzler (FIRMessagingRemoteNotificationsProxyTest)
+ (void)resetProxyOriginalDelegateOnceToken;
@end

/** Category for FIRAuth to expose FIRComponentRegistrant conformance. */
@interface FIRAuth () <FIRLibrary>
@end

/** @class FIRAuthTests
    @brief Tests for @c FIRAuth.
 */
@interface FIRAuthTests : XCTestCase
#if TARGET_OS_IOS
/// A partial mock of `[FIRAuth auth].tokenManager`
@property(nonatomic, strong) id mockTokenManager;
/// A partial mock of `[FIRAuth auth].notificationManager`
@property(nonatomic, strong) id mockNotificationManager;
/// A partial mock of `[FIRAuth auth].authURLPresenter`
@property(nonatomic, strong) id mockAuthURLPresenter;
/// An application delegate instance returned by `self.mockApplication.delegate`
@property(nonatomic, strong) FIRAuthAppDelegate *fakeApplicationDelegate;
#endif  // TARGET_OS_IOS
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
      @"iss" : @"https://accounts.google.com\\",
      @"email" : kGoogleEmail,
      @"given_name" : @"User",
      @"family_name" : @"Doe"
    };
  });
  return kGoogleProfile;
}

- (void)setUp {
  [super setUp];

#if TARGET_OS_IOS
  // Make sure the `self.fakeApplicationDelegate` will be swizzled on FIRAuth init.
  [GULAppDelegateSwizzler resetProxyOriginalDelegateOnceToken];

  self.fakeApplicationDelegate = [[FIRAuthAppDelegate alloc] init];
  [[GULAppDelegateSwizzler sharedApplication]
      setDelegate:(id<UIApplicationDelegate>)self.fakeApplicationDelegate];
#endif  // TARGET_OS_IOS

  _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
  [FIRAuthBackend2 setBackendImplementation:_mockBackend];
  [FIRApp resetAppForAuthUnitTests];

  // Set FIRAuthDispatcher implementation in order to save the token refresh task for later
  // execution.
  [[FIRAuthDispatcher sharedInstance]
      setDispatchAfterImplementation:^(NSTimeInterval delay, dispatch_queue_t _Nonnull queue,
                                       void (^task)(void)) {
        XCTAssertNotNil(task);
        XCTAssert(delay > 0);
        XCTAssertEqualObjects(FIRAuthGlobalWorkQueue(), queue);
        self->_FIRAuthDispatcherCallback = task;
      }];

#if TARGET_OS_IOS
  // Wait until FIRAuth initialization completes
  [self waitForAuthGlobalWorkQueueDrain];
  self.mockTokenManager = OCMPartialMock([FIRAuth auth].tokenManager);
  self.mockNotificationManager = OCMPartialMock([FIRAuth auth].notificationManager);
  self.mockAuthURLPresenter = OCMPartialMock([FIRAuth auth].authURLPresenter);
#endif  // TARGET_OS_IOS
}

- (void)tearDown {
  [FIRAuthBackend2 setDefaultBackendImplementationWithrpcIssuer:nil];
  [[FIRAuthDispatcher sharedInstance] setDispatchAfterImplementation:nil];

#if TARGET_OS_IOS
  [self.mockAuthURLPresenter stopMocking];
  self.mockAuthURLPresenter = nil;
  [self.mockNotificationManager stopMocking];
  self.mockNotificationManager = nil;
  [self.mockTokenManager stopMocking];
  self.mockTokenManager = nil;
  self.fakeApplicationDelegate = nil;
#endif  // TARGET_OS_IOS

  [super tearDown];
}

#pragma mark - Server API Tests

#if TARGET_OS_IOS
/** @fn testPhoneAuthSuccess
    @brief Tests the flow of a successful @c signInWithCredential:completion for phone auth.
 */
#ifdef TODO_SWIFT
- (void)testPhoneAuthSuccess {
  OCMExpect([_mockBackend verifyPhoneNumber:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPhoneNumberRequest *_Nullable request,
                       FIRVerifyPhoneNumberResponseCallback callback) {
        XCTAssertEqualObjects(request.verificationCode, kVerificationCode);
        XCTAssertEqualObjects(request.verificationID, kVerificationID);
        XCTAssertEqual(request.operation, FIRAuthOperationTypeSignUpOrSignIn);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyPhoneResponse = OCMClassMock([FIRVerifyPhoneNumberResponse class]);
          [self stubTokensWithMockResponse:mockVerifyPhoneResponse];
          // Stub isNewUser flag in the response.
          OCMStub([mockVerifyPhoneResponse isNewUser]).andReturn(YES);
          callback(mockVerifyPhoneResponse, nil);
        });
      });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                   verificationCode:kVerificationCode];

  [[FIRAuth auth] signInWithCredential:credential
                            completion:^(FIRAuthDataResult *_Nullable authDataResult,
                                         NSError *_Nullable error) {
                              XCTAssertTrue([NSThread isMainThread]);
                              [self assertUser:authDataResult.user];
                              XCTAssertTrue(authDataResult.additionalUserInfo.isNewUser);
                              XCTAssertNil(error);
                              [expectation fulfill];
                            }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}
#endif
/** @fn testPhoneAuthMissingVerificationCode
    @brief Tests the flow of an unsuccessful @c signInWithCredential:completion for phone auth due
        to an empty verification code
 */
- (void)testPhoneAuthMissingVerificationCode {
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                   verificationCode:@""];

  [[FIRAuth auth]
      signInWithCredential:credential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(result);
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
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:@""
                                                   verificationCode:kVerificationCode];

  [[FIRAuth auth]
      signInWithCredential:credential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(result);
                  XCTAssertEqual(error.code, FIRAuthErrorCodeMissingVerificationID);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}
#endif

#ifdef TODO_SWIFT
/** @fn testSignInWithEmailLinkCredentialSuccess
    @brief Tests the flow of a successfully @c signInWithCredential:completion: call with an
        email sign-in link credential using FIREmailAuthProvider.
 */

- (void)testSignInWithEmailLinkCredentialSuccess {
  NSString *fakeCode = @"testoobcode";
  OCMExpect([_mockBackend emailLinkSignin:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIREmailLinkSignInRequest *_Nullable request,
                       FIREmailLinkSigninResponseCallback callback) {
        XCTAssertEqualObjects(request.email, kEmail);
        XCTAssertEqualObjects(request.oobCode, fakeCode);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockEmailLinkSigninResponse = OCMClassMock([FIREmailLinkSignInResponse class]);
          [self stubTokensWithMockResponse:mockEmailLinkSigninResponse];
          callback(mockEmailLinkSigninResponse, nil);
        });
      });
  [self expectGetAccountInfo];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *emailCredential =
      [FIREmailAuthProvider credentialWithEmail:kEmail link:kFakeEmailSignInlink];
  [[FIRAuth auth]
      signInWithCredential:emailCredential
                completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNotNil(authResult.user);
                  XCTAssertEqualObjects(authResult.user.refreshToken, kRefreshToken);
                  XCTAssertFalse(authResult.user.anonymous);
                  XCTAssertEqualObjects(authResult.user.email, kEmail);
                  XCTAssertNil(error);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUser:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithEmailLinkCredentialFailure
    @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
        email-email sign-in link credential using FIREmailAuthProvider.
 */
- (void)testSignInWithEmailLinkCredentialFailure {
  OCMExpect([_mockBackend emailLinkSignin:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils userDisabledErrorWithMessage:nil]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *emailCredential =
      [FIREmailAuthProvider credentialWithEmail:kEmail link:kFakeEmailSignInlink];
  [[FIRAuth auth]
      signInWithCredential:emailCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(result);
                  XCTAssertEqual(error.code, FIRAuthErrorCodeUserDisabled);
                  XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
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
        XCTAssertEqualObjects(request.password, kFakePassword);
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
  FIRAuthCredential *emailCredential = [FIREmailAuthProvider credentialWithEmail:kEmail
                                                                        password:kFakePassword];
  [[FIRAuth auth]
      signInWithCredential:emailCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  [self assertUser:result.user];
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
  FIRAuthCredential *emailCredential = [FIREmailAuthProvider credentialWithEmail:kEmail
                                                                        password:kFakePassword];
  [[FIRAuth auth]
      signInWithCredential:emailCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(result);
                  XCTAssertEqual(error.code, FIRAuthErrorCodeUserDisabled);
                  XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}
#endif
/** @fn testSignInWithEmailCredentialEmptyPassword
    @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
        email-password credential using an empty password. This error occurs on the client side,
        so there is no need to fake an RPC response.
 */
- (void)testSignInWithEmailCredentialEmptyPassword {
  NSString *emptyString = @"";
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *emailCredential = [FIREmailAuthProvider credentialWithEmail:kEmail
                                                                        password:emptyString];
  [[FIRAuth auth]
      signInWithCredential:emailCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertEqual(error.code, FIRAuthErrorCodeWrongPassword);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

#if TARGET_OS_IOS
/** @fn testSignInWithProviderSuccess
    @brief Tests a successful @c signInWithProvider:UIDelegate:completion: call with an OAuth
        provider configured for Google.
 */
#ifdef TODO_SWIFT
- (void)testSignInWithProviderSuccess {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProvider.id);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse federatedID]).andReturn(kGoogleID);
          OCMStub([mockVerifyAssertionResponse providerID]).andReturn(FIRGoogleAuthProvider.id);
          OCMStub([mockVerifyAssertionResponse localID]).andReturn(kLocalID);
          OCMStub([mockVerifyAssertionResponse displayName]).andReturn(kGoogleDisplayName);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  [self expectGetAccountInfoGoogle];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  id mockProvider = OCMClassMock([FIROAuthProvider class]);
  OCMExpect([mockProvider getCredentialWithUIDelegate:[OCMArg any] completion:[OCMArg any]])
      .andCallBlock2(^(id<FIRAuthUIDelegate> delegate,
                       void (^callback)(FIRAuthCredential *_Nullable, NSError *_Nullable)) {
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          FIROAuthCredential *credential =
              [[FIROAuthCredential alloc] initWithProviderID:FIRGoogleAuthProvider.id
                                                   sessionID:kOAuthSessionID
                                      OAuthResponseURLString:kOAuthRequestURI];
          callback(credential, nil);
        });
      });
  [[FIRAuth auth]
      signInWithProvider:mockProvider
              UIDelegate:nil
              completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                XCTAssertTrue([NSThread isMainThread]);
                [self assertUserGoogle:authResult.user];
                XCTAssertNil(error);
                [expectation fulfill];
              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithProviderFailure
    @brief Tests a failed @c signInWithProvider:UIDelegate:completion: call with the error code
        FIRAuthErrorCodeWebSignInUserInteractionFailure.
 */
- (void)testSignInWithProviderFailure {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils
          webSignInUserInteractionFailureWithReason:kFakeWebSignInUserInteractionFailureReason]);
  [[FIRAuth auth] signOut:NULL];
  id mockProvider = OCMClassMock([FIROAuthProvider class]);
  OCMExpect([mockProvider getCredentialWithUIDelegate:[OCMArg any] completion:[OCMArg any]])
      .andCallBlock2(^(id<FIRAuthUIDelegate> delegate,
                       void (^callback)(FIRAuthCredential *_Nullable, NSError *_Nullable)) {
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          FIROAuthCredential *credential =
              [[FIROAuthCredential alloc] initWithProviderID:FIRGoogleAuthProvider.id
                                                   sessionID:kOAuthSessionID
                                      OAuthResponseURLString:kOAuthRequestURI];
          callback(credential, nil);
        });
      });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth]
      signInWithProvider:mockProvider
              UIDelegate:nil
              completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                XCTAssertTrue([NSThread isMainThread]);
                XCTAssertNil(authResult);
                XCTAssertEqual(error.code, FIRAuthErrorCodeWebSignInUserInteractionFailure);
                XCTAssertEqualObjects(error.userInfo[NSLocalizedFailureReasonErrorKey],
                                      kFakeWebSignInUserInteractionFailureReason);
                [expectation fulfill];
              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
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
        XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProvider.id);
        XCTAssertEqualObjects(request.providerIDToken, kGoogleIDToken);
        XCTAssertEqualObjects(request.providerAccessToken, kGoogleAccessToken);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse needConfirmation]).andReturn(YES);
          OCMStub([mockVerifyAssertionResponse email]).andReturn(kEmail);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth]
      signInWithCredential:googleCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertEqual(error.code, FIRAuthErrorCodeAccountExistsWithDifferentCredential);
                  XCTAssertEqualObjects(error.userInfo[FIRAuthErrors.FIRAuthErrorUserInfoEmailKey],
                                        kEmail);
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
        XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProvider.id);
        XCTAssertEqualObjects(request.providerIDToken, kGoogleIDToken);
        XCTAssertEqualObjects(request.providerAccessToken, kGoogleAccessToken);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse federatedID]).andReturn(kGoogleID);
          OCMStub([mockVerifyAssertionResponse providerID]).andReturn(FIRGoogleAuthProvider.id);
          OCMStub([mockVerifyAssertionResponse localID]).andReturn(kLocalID);
          OCMStub([mockVerifyAssertionResponse displayName]).andReturn(kGoogleDisplayName);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  [self expectGetAccountInfoGoogle];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth]
      signInWithCredential:googleCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  [self assertUserGoogle:result.user];
                  XCTAssertNil(error);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testSignInWithOAuthCredentialSuccess
    @brief Tests the flow of a successful @c signInWithCredential:completion: call with a generic
        OAuth credential (In this case, configured for the Google IDP).
 */
- (void)testSignInWithOAuthCredentialSuccess {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProvider.id);
        XCTAssertEqualObjects(request.requestURI, kOAuthRequestURI);
        XCTAssertEqualObjects(request.sessionID, kOAuthSessionID);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse federatedID]).andReturn(kGoogleID);
          OCMStub([mockVerifyAssertionResponse providerID]).andReturn(FIRGoogleAuthProvider.id);
          OCMStub([mockVerifyAssertionResponse localID]).andReturn(kLocalID);
          OCMStub([mockVerifyAssertionResponse displayName]).andReturn(kGoogleDisplayName);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  [self expectGetAccountInfoGoogle];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  id mockProvider = OCMClassMock([FIROAuthProvider class]);
  OCMExpect([mockProvider getCredentialWithUIDelegate:[OCMArg any] completion:[OCMArg any]])
      .andCallBlock2(^(id<FIRAuthUIDelegate> delegate,
                       void (^callback)(FIRAuthCredential *_Nullable, NSError *_Nullable)) {
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          FIROAuthCredential *credential =
              [[FIROAuthCredential alloc] initWithProviderID:FIRGoogleAuthProvider.id
                                                   sessionID:kOAuthSessionID
                                      OAuthResponseURLString:kOAuthRequestURI];
          callback(credential, nil);
        });
      });
  [mockProvider
      getCredentialWithUIDelegate:nil
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(OAuthCredential.OAuthResponseURLString,
                                               kOAuthRequestURI);
                         XCTAssertEqualObjects(OAuthCredential.sessionID, kOAuthSessionID);
                         [[FIRAuth auth] signInWithCredential:OAuthCredential
                                                   completion:^(FIRAuthDataResult *_Nullable result,
                                                                NSError *_Nullable error) {
                                                     XCTAssertTrue([NSThread isMainThread]);
                                                     [self assertUserGoogle:result.user];
                                                     XCTAssertNil(error);
                                                     [expectation fulfill];
                                                   }];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}
#endif
#endif  // TARGET_OS_IOS
#ifdef TODO_SWIFT
/** @fn testSignInWithCredentialSuccess
    @brief Tests the flow of a successful @c signInWithCredential:completion: call
        with an Google Sign-In credential.
 */
- (void)testSignInWithCredentialSuccess {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.providerID, FIRGoogleAuthProvider.id);
        XCTAssertEqualObjects(request.providerIDToken, kGoogleIDToken);
        XCTAssertEqualObjects(request.providerAccessToken, kGoogleAccessToken);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse federatedID]).andReturn(kGoogleID);
          OCMStub([mockVerifyAssertionResponse providerID]).andReturn(FIRGoogleAuthProvider.id);
          OCMStub([mockVerifyAssertionResponse localID]).andReturn(kLocalID);
          OCMStub([mockVerifyAssertionResponse displayName]).andReturn(kGoogleDisplayName);
          OCMStub([mockVerifyAssertionResponse profile]).andReturn([[self class] googleProfile]);
          OCMStub([mockVerifyAssertionResponse username]).andReturn(kDisplayName);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  [self expectGetAccountInfoGoogle];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
  [[FIRAuth auth]
      signInWithCredential:googleCredential
                completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  [self assertUserGoogle:authResult.user];
                  XCTAssertEqualObjects(authResult.additionalUserInfo.profile,
                                        [[self class] googleProfile]);
                  XCTAssertEqualObjects(authResult.additionalUserInfo.username, kDisplayName);
                  XCTAssertEqualObjects(authResult.additionalUserInfo.providerID,
                                        FIRGoogleAuthProvider.id);
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
  [[FIRAuth auth]
      signInWithCredential:googleCredential
                completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(result.user);
                  XCTAssertEqual(error.code, FIRAuthErrorCodeEmailAlreadyInUse);
                  XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}
#ifdef TODO_SWIFT
/** @fn testSignInWithAppleCredentialFullNameInRequest
    @brief Tests the flow of a successful @c signInWithCredential:completion: call
        with an Apple Sign-In credential with a full name. This test differentiates from
        @c testSignInWithCredentialSuccess only in verifying the full name.
 */
- (void)testSignInWithAppleCredentialFullNameInRequestSuccess {
  NSPersonNameComponents *fullName = [[NSPersonNameComponents alloc] init];
  fullName.givenName = kFakeGivenName;
  fullName.familyName = kFakeFamilyName;
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.providerID, kAppleAuthProviderID);
        XCTAssertEqualObjects(request.providerIDToken, kAppleIDToken);
        // Verify that the full name is passed to the backend request.
        XCTAssertEqualObjects(request.fullName, fullName);
        XCTAssertTrue(request.returnSecureToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
          OCMStub([mockVerifyAssertionResponse providerID]).andReturn(kAppleAuthProviderID);
          [self stubTokensWithMockResponse:mockVerifyAssertionResponse];
          callback(mockVerifyAssertionResponse, nil);
        });
      });
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.accessToken, kAccessToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockAppleUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
          OCMStub([mockAppleUserInfo providerID]).andReturn(kAppleAuthProviderID);
          id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
          OCMStub([mockGetAccountInfoResponseUser providerUserInfo])
              .andReturn((@[ mockAppleUserInfo ]));
          id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
          OCMStub([mockGetAccountInfoResponse users]).andReturn(@[
            mockGetAccountInfoResponseUser
          ]);
          callback(mockGetAccountInfoResponse, nil);
        });
      });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *appleCredential = [FIROAuthProvider appleCredentialWithIDToken:kAppleIDToken
                                                                           rawNonce:nil
                                                                           fullName:fullName];
  [[FIRAuth auth]
      signInWithCredential:appleCredential
                completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                  XCTAssertTrue([NSThread isMainThread]);
                  XCTAssertNil(error);
                  [expectation fulfill];
                }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNotNil([FIRAuth auth].currentUser);
  OCMVerifyAll(_mockBackend);
}

#ifdef TODO_SWIFT
/** @fn testUpdateCurrentUserFailure
    @brief Tests the flow of a failed @c updateCurrentUser:completion:
        call.
 */
- (void)testUpdateCurrentUserFailure {
  NSString *kTestAccessToken = @"fakeAccessToken";
  NSString *kTestAPIKey = @"fakeAPIKey";
  [self waitForSignInWithAccessToken:kTestAccessToken APIKey:kTestAPIKey completion:nil];
  NSString *kTestAPIKey2 = @"fakeAPIKey2";
  FIRUser *user2 = [FIRAuth auth].currentUser;
  user2.requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey2
                                                                             appID:kFirebaseAppID
                                                                              auth:nil];
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils invalidAPIKeyError]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] updateCurrentUser:user2
                         completion:^(NSError *_Nullable error) {
                           XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidAPIKey);
                           [expectation fulfill];
                         }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateCurrentUserFailureNetworkError
    @brief Tests the flow of a failed @c updateCurrentUser:completion:
        call with a network error.
 */
- (void)testUpdateCurrentUserFailureNetworkError {
  NSString *kTestAPIKey = @"fakeAPIKey";
  NSString *kTestAccessToken = @"fakeAccessToken";
  [self waitForSignInWithAccessToken:kTestAccessToken APIKey:kTestAPIKey completion:nil];
  NSString *kTestAPIKey2 = @"fakeAPIKey2";
  FIRUser *user2 = [FIRAuth auth].currentUser;
  user2.requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey2
                                                                             appID:kFirebaseAppID
                                                                              auth:nil];
  NSError *underlyingError = [NSError errorWithDomain:@"Test Error" code:1 userInfo:nil];
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andDispatchError2([FIRAuthErrorUtils networkErrorWithUnderlyingError:underlyingError]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] updateCurrentUser:user2
                         completion:^(NSError *_Nullable error) {
                           XCTAssertEqual(error.code, FIRAuthErrorCodeNetworkError);
                           [expectation fulfill];
                         }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateCurrentUserFailureNUllUser
    @brief Tests the flow of a failed @c updateCurrentUser:completion:
        call with FIRAuthErrorCodeNullUser.
 */
- (void)testUpdateCurrentUserFailureNUllUser {
  NSString *kTestAccessToken = @"fakeAccessToken";
  NSString *kTestAPIKey = @"fakeAPIKey";
  [self waitForSignInWithAccessToken:kTestAccessToken APIKey:kTestAPIKey completion:nil];
  FIRUser *fakeNilUser = nil;
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] updateCurrentUser:fakeNilUser
                         completion:^(NSError *_Nullable error) {
                           XCTAssertEqual(error.code, FIRAuthErrorCodeNullUser);
                           [expectation fulfill];
                         }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateCurrentUserFailureTenantIDMismatch
 @brief Tests the flow of a failed @c updateCurrentUser:completion:
 call with FIRAuthErrorCodeTenantIDMismatch.
 */
- (void)testUpdateCurrentUserFailureTenantIDMismatch {
  // User without tenant id
  [self waitForSignInWithAccessToken:kAccessToken APIKey:kAPIKey completion:nil];
  FIRUser *user1 = [FIRAuth auth].currentUser;
  [[FIRAuth auth] signOut:nil];

  // User with tenant id "tenant-id"
  [FIRAuth auth].tenantID = @"tenant-id-1";
  NSString *kTestAccessToken2 = @"fakeAccessToken2";
  [self waitForSignInWithAccessToken:kTestAccessToken2 APIKey:kAPIKey completion:nil];
  FIRUser *user2 = [FIRAuth auth].currentUser;

  [[FIRAuth auth] signOut:nil];
  [FIRAuth auth].tenantID = @"tenant-id-2";
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] updateCurrentUser:user1
                         completion:^(NSError *_Nullable error) {
                           XCTAssertEqual(error.code, FIRAuthErrorCodeTenantIDMismatch);
                           [expectation1 fulfill];
                         }];

  [[FIRAuth auth] signOut:nil];
  [FIRAuth auth].tenantID = @"tenant-id-2";
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] updateCurrentUser:user2
                         completion:^(NSError *_Nullable error) {
                           XCTAssertEqual(error.code, FIRAuthErrorCodeTenantIDMismatch);
                           [expectation2 fulfill];
                         }];

  [[FIRAuth auth] signOut:nil];
  [FIRAuth auth].tenantID = nil;
  XCTestExpectation *expectation3 = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] updateCurrentUser:user2
                         completion:^(NSError *_Nullable error) {
                           XCTAssertEqual(error.code, FIRAuthErrorCodeTenantIDMismatch);
                           [expectation3 fulfill];
                         }];

  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateCurrentUserSuccess
    @brief Tests the flow of a successful @c updateCurrentUser:completion:
        call with a network error.
 */
- (void)testUpdateCurrentUserSuccess {
  // Sign in with the first user.
  [self waitForSignInWithAccessToken:kAccessToken APIKey:kAPIKey completion:nil];

  FIRUser *user1 = [FIRAuth auth].currentUser;
  NSString *kTestAPIKey = @"fakeAPIKey";
  user1.requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey
                                                                             appID:kFirebaseAppID
                                                                              auth:nil];
  [[FIRAuth auth] signOut:nil];

  NSString *kTestAccessToken2 = @"fakeAccessToken2";
  [self waitForSignInWithAccessToken:kTestAccessToken2 APIKey:kAPIKey completion:nil];
  FIRUser *user2 = [FIRAuth auth].currentUser;

  [self expectGetAccountInfoWithAccessToken:kAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  // Current user should now be user2.
  XCTAssertEqualObjects([FIRAuth auth].currentUser, user2);
  [[FIRAuth auth] updateCurrentUser:user1
                         completion:^(NSError *_Nullable error) {
                           XCTAssertNil(error);
                           // Current user should now be user1.
                           XCTAssertEqualObjects([FIRAuth auth].currentUser, user1);
                           XCTAssertNotEqualObjects([FIRAuth auth].currentUser, user2);
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
#endif
/** @fn testIsSignInWithEmailLink
    @brief Tests the @c isSignInWithEmailLink: method.
*/
- (void)testIsSignInWithEmailLink {
  XCTAssertTrue([[FIRAuth auth] isSignInWithEmailLink:kFakeEmailSignInlink]);
  XCTAssertTrue([[FIRAuth auth] isSignInWithEmailLink:kFakeEmailSignInDeeplink]);
  XCTAssertFalse([[FIRAuth auth] isSignInWithEmailLink:kBadSignInEmailLink]);
  XCTAssertFalse([[FIRAuth auth] isSignInWithEmailLink:@""]);
}
#ifdef TODO_SWIFT
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
  FIRIDTokenDidChangeListenerHandle handle = [[FIRAuth auth] addIDTokenDidChangeListener:listener];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Listener should fire for signing in.
  expectation = [self expectationWithDescription:@"sign-in"];
  shouldHaveUser = YES;
  [self waitForSignIn];

  // Listener should fire for signing in again as the same user with another access token.
  expectation = [self expectationWithDescription:@"sign-in again"];
  shouldHaveUser = YES;
  [self waitForSignInWithAccessToken:kNewAccessToken APIKey:nil completion:nil];

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
#endif
/** @fn testUseEmulator
    @brief Tests the @c useEmulatorWithHost:port: method.
 */
- (void)testUseEmulator {
  [[FIRAuth auth] useEmulatorWithHost:@"host" port:12345];

  XCTAssertEqualObjects(@"host:12345", [FIRAuth auth].requestConfiguration.emulatorHostAndPort);
#if TARGET_OS_IOS
  XCTAssertTrue([FIRAuth auth].settings.isAppVerificationDisabledForTesting);
#endif
}

/** @fn testUseEmulatorNeverCalled
    @brief Tests that the emulatorHostAndPort stored in @c FIRAuthRequestConfiguration is nil if the
   @c useEmulatorWithHost:port: is not called.
 */
- (void)testUseEmulatorNeverCalled {
  XCTAssertEqualObjects(nil, [FIRAuth auth].requestConfiguration.emulatorHostAndPort);
#if TARGET_OS_IOS
  XCTAssertFalse([FIRAuth auth].settings.isAppVerificationDisabledForTesting);
#endif
}

/** @fn testUseEmulatorIPv6Address
    @brief Tests the @c useEmulatorWithHost:port: method with an IPv6 host address.
 */
- (void)testUseEmulatorIPv6Address {
  [[FIRAuth auth] useEmulatorWithHost:@"::1" port:12345];

  XCTAssertEqualObjects(@"[::1]:12345", [FIRAuth auth].requestConfiguration.emulatorHostAndPort);
#if TARGET_OS_IOS
  XCTAssertTrue([FIRAuth auth].settings.isAppVerificationDisabledForTesting);
#endif
}

#pragma mark - Automatic Token Refresh Tests.
#ifdef TODO_SWIFT
/** @fn testAutomaticTokenRefresh
    @brief Tests a successful flow to automatically refresh tokens for a signed in user.
 */
- (void)testAutomaticTokenRefresh {
  [[FIRAuth auth] signOut:NULL];

  // Enable auto refresh
  [self enableAutoTokenRefresh];

  // Sign in a user.
  [self waitForSignIn];

  // Set up expectation for secureToken RPC made by token refresh task. We call this twice, because
  // we retry once if the access token is already expired.
  [self mockSecureTokenResponseWithError:nil];
  [self mockSecureTokenResponseWithError:nil];

  // Verify that the current user's access token is the "old" access token before automatic token
  // refresh.
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(self->_FIRAuthDispatcherCallback);
    self->_FIRAuthDispatcherCallback();
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
    XCTAssertNotNil(self->_FIRAuthDispatcherCallback);
    self->_FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Verify that the user is nil after failed attempt to refresh tokens caused signed out.
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
    XCTAssertNotNil(self->_FIRAuthDispatcherCallback);
    self->_FIRAuthDispatcherCallback();
    self->_FIRAuthDispatcherCallback = nil;
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // The old access token should still be the current user's access token and not the new access
  // token (kNewAccessToken).
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Set up expectation for secureToken RPC made by a successful attempt to refresh tokens. We call
  // this twice, because we retry once if the access token is already expired.
  [self mockSecureTokenResponseWithError:nil];
  [self mockSecureTokenResponseWithError:nil];

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(self->_FIRAuthDispatcherCallback);
    self->_FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Verify that current user's access token is the "new" access token provided in the mock secure
  // token response during automatic token refresh.
  XCTAssertEqualObjects([FIRAuth auth].currentUser.rawAccessToken, kNewAccessToken);
  OCMVerifyAll(_mockBackend);
}

#if TARGET_OS_IOS
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
      postNotificationName:UIApplicationDidBecomeActiveNotification
                    object:nil];

  // Verify that current user is still valid with old access token.
  XCTAssertEqualObjects(kAccessToken, [FIRAuth auth].currentUser.rawAccessToken);

  // Set up expectation for secureToken RPC made by a successful attempt to refresh tokens. We call
  // this twice, because we retry once if the access token is already expired.
  [self mockSecureTokenResponseWithError:nil];
  [self mockSecureTokenResponseWithError:nil];

  // Execute saved token refresh task.
  XCTestExpectation *dispatchAfterExpectation =
      [self expectationWithDescription:@"dispatchAfterExpectation"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
    XCTAssertNotNil(self->_FIRAuthDispatcherCallback);
    self->_FIRAuthDispatcherCallback();
    [dispatchAfterExpectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  // Verify that current user is still valid with new access token.
  XCTAssertEqualObjects(kNewAccessToken, [FIRAuth auth].currentUser.rawAccessToken);
  OCMVerifyAll(_mockBackend);
}
#endif
#endif  // TODO_SWIFT
#if TARGET_OS_IOS
#pragma mark - Application Delegate tests
#ifdef TODO_SWIFT
- (void)testAppDidRegisterForRemoteNotifications_APNSTokenUpdated {
  NSData *apnsToken = [NSData data];

  OCMExpect([self.mockTokenManager setToken:[OCMArg checkWithBlock:^BOOL(FIRAuthAPNSToken *token) {
                                     XCTAssertEqual(token.data, apnsToken);
                                     XCTAssertEqual(token.type, FIRAuthAPNSTokenTypeUnknown);
                                     return YES;
                                   }]]);

  [self.fakeApplicationDelegate application:[GULAppDelegateSwizzler sharedApplication]
      didRegisterForRemoteNotificationsWithDeviceToken:apnsToken];

  [self.mockTokenManager verify];
}
#endif

- (void)testAppDidFailToRegisterForRemoteNotifications_TokenManagerCancels {
  NSError *error = [NSError errorWithDomain:@"FIRAuthTests" code:-1 userInfo:nil];

  OCMExpect([self.mockTokenManager cancelWithError:error]);

  [self.fakeApplicationDelegate application:[GULAppDelegateSwizzler sharedApplication]
      didFailToRegisterForRemoteNotificationsWithError:error];

  [self.mockTokenManager verify];
}

- (void)testAppDidReceiveRemoteNotification_NotificationManagerHandleCanNotification {
  NSDictionary *notification = @{@"test" : @""};

  OCMExpect([self.mockNotificationManager canHandleNotification:notification]);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [self.fakeApplicationDelegate application:[GULAppDelegateSwizzler sharedApplication]
               didReceiveRemoteNotification:notification];
#pragma clang diagnostic pop

  [self.mockNotificationManager verify];
}

- (void)testAppDidReceiveRemoteNotificationWithCompletion_NotificationManagerHandleCanNotification {
  NSDictionary *notification = @{@"test" : @""};

  OCMExpect([self.mockNotificationManager canHandleNotification:notification]);

  [self.fakeApplicationDelegate application:[GULAppDelegateSwizzler sharedApplication]
               didReceiveRemoteNotification:notification
                     fetchCompletionHandler:^(UIBackgroundFetchResult result){
                     }];

  [self.mockNotificationManager verify];
}

- (void)testAppOpenURL_AuthPresenterCanHandleURL {
  if (@available(iOS 9.0, *)) {
    // 'application:openURL:options:' is only available on iOS 9.0 or newer.
    NSURL *url = [NSURL URLWithString:@"https://localhost"];

    OCMExpect([self.mockAuthURLPresenter canHandleURL:url]).andReturn(YES);

    XCTAssertTrue([self.fakeApplicationDelegate
        application:[GULAppDelegateSwizzler sharedApplication]
            openURL:url
            options:@{}]);

    [self.mockAuthURLPresenter verify];
  }
}

- (void)testAppOpenURLWithSourceApplication_AuthPresenterCanHandleURL {
  NSURL *url = [NSURL URLWithString:@"https://localhost"];

  OCMExpect([self.mockAuthURLPresenter canHandleURL:url]).andReturn(YES);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  XCTAssertTrue([self.fakeApplicationDelegate application:[GULAppDelegateSwizzler sharedApplication]
                                                  openURL:url
                                        sourceApplication:@""
                                               annotation:[[NSObject alloc] init]]);
#pragma clang diagnostic pop

  [self.mockAuthURLPresenter verify];
}

#endif  // TARGET_OS_IOS

#pragma mark - Interoperability Tests

/** @fn testComponentsBeingRegistered
 @brief Tests that Auth provides the necessary components for interoperability with other SDKs.
 */
- (void)testComponentsBeingRegistered {
  // Verify that the components are registered properly. Check the count, because any time a new
  // component is added it should be added to the test suite as well.
  NSArray<FIRComponent *> *components = [FIRAuth componentsToRegister];
  XCTAssertTrue(components.count == 1);

  FIRComponent *component = [components firstObject];
  XCTAssert(component.protocol == @protocol(FIRAuthInterop));
}

#pragma mark - Helpers
#if SWIFT_TODO
/** @fn mockSecureTokenResponseWithError:
    @brief Set up expectation for secureToken RPC.
    @param error The error that the mock should return if any.
 */
- (void)mockSecureTokenResponseWithError:(nullable NSError *)error {
  // Set up expectation for secureToken RPC made by a successful attempt to refresh tokens.
  XCTestExpectation *secureTokenResponseExpectation =
      [self expectationWithDescription:@"secureTokenResponseExpectation"];
  OCMExpect([_mockBackend secureToken:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRSecureTokenRequest *_Nullable request, FIRSecureTokenResponseCallback callback) {
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
#endif
/** @fn enableAutoTokenRefresh
    @brief Enables automatic token refresh by invoking FIRAuth's implementation of FIRApp's
        |getTokenWithImplementation|.
 */
- (void)enableAutoTokenRefresh {
  XCTestExpectation *expectation = [self expectationWithDescription:@"autoTokenRefreshcallback"];
  [[FIRAuth auth] getTokenForcingRefresh:NO
                            withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                              [expectation fulfill];
                            }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
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
#ifdef TODO_SWIFT
/** @fn expectGetAccountInfo
    @brief Expects a GetAccountInfo request on the mock backend and calls back with fake account
        data.
 */
- (void)expectGetAccountInfo {
  [self expectGetAccountInfoWithAccessToken:kAccessToken];
}

/** @fn expectGetAccountInfoWithAccessToken
    @param accessToken The access token for the user to check against.
    @brief Expects a GetAccountInfo request on the mock backend and calls back with fake account
        data.
 */
- (void)expectGetAccountInfoWithAccessToken:(NSString *)accessToken {
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
        XCTAssertEqualObjects(request.APIKey, kAPIKey);
        XCTAssertEqualObjects(request.accessToken, accessToken);
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
          OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
          OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kDisplayName);
          OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
          OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
          id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
          OCMStub([mockGetAccountInfoResponse users]).andReturn(@[
            mockGetAccountInfoResponseUser
          ]);
          callback(mockGetAccountInfoResponse, nil);
        });
      });
}
#endif
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
#ifdef TODO_SWIFT
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
          OCMStub([mockGoogleUserInfo providerID]).andReturn(FIRGoogleAuthProvider.id);
          OCMStub([mockGoogleUserInfo displayName]).andReturn(kGoogleDisplayName);
          OCMStub([mockGoogleUserInfo federatedID]).andReturn(kGoogleID);
          OCMStub([mockGoogleUserInfo email]).andReturn(kGoogleEmail);
          id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
          OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
          OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kDisplayName);
          OCMStub([mockGetAccountInfoResponseUser providerUserInfo])
              .andReturn((@[ mockGoogleUserInfo ]));
          id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
          OCMStub([mockGetAccountInfoResponse users]).andReturn(@[
            mockGetAccountInfoResponseUser
          ]);
          callback(mockGetAccountInfoResponse, nil);
        });
      });
}
#endif
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
  XCTAssertEqualObjects(googleUserInfo.providerID, FIRGoogleAuthProvider.id);
  XCTAssertEqualObjects(googleUserInfo.uid, kGoogleID);
  XCTAssertEqualObjects(googleUserInfo.displayName, kGoogleDisplayName);
  XCTAssertEqualObjects(googleUserInfo.email, kGoogleEmail);
}
#ifdef TODO_SWIFT
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
          OCMStub([mockGetAccountInfoResponse users]).andReturn(@[
            mockGetAccountInfoResponseUser
          ]);
          callback(mockGetAccountInfoResponse, nil);
        });
      });
}
#endif
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
#ifdef TODO_SWIFT
/** @fn waitForSignIn
    @brief Signs in a user to prepare for tests.
    @remarks This method also waits for all other pending @c XCTestExpectation instances.
 */
- (void)waitForSignIn {
  [self waitForSignInWithAccessToken:kAccessToken APIKey:nil completion:nil];
}

/** @fn waitForSignInWithAccessToken:
    @brief Signs in a user to prepare for tests.
    @param accessToken The access token for the user to have.
    @param APIKey Optionally, The API key associated with the user.
    @param completion Optionally, The completion invoked at the end of the flow.
    @remarks This method also waits for all other pending @c XCTestExpectation instances.
 */
- (void)waitForSignInWithAccessToken:(NSString *)accessToken
                              APIKey:(nullable NSString *)APIKey
                          completion:(nullable FIRAuthResultCallback)completion {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                       FIRVerifyPasswordResponseCallback callback) {
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          id mockVerifyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
          OCMStub([mockVerifyPasswordResponse IDToken]).andReturn(accessToken);
          OCMStub([mockVerifyPasswordResponse approximateExpirationDate])
              .andReturn([NSDate dateWithTimeIntervalSinceNow:kAccessTokenTimeToLive]);
          OCMStub([mockVerifyPasswordResponse refreshToken]).andReturn(kRefreshToken);
          callback(mockVerifyPasswordResponse, nil);
        });
      });
  [self expectGetAccountInfoWithAccessToken:accessToken];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signInWithEmail:kEmail
                         password:kFakePassword
                       completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                         result.user.requestConfiguration =
                             [[FIRAuthRequestConfiguration alloc] initWithAPIKey:APIKey
                                                                           appID:kFirebaseAppID
                                                                            auth:nil];
                         [expectation fulfill];
                         if (completion) {
                           completion(result.user, error);
                         }
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  XCTAssertNotNil([FIRAuth auth].currentUser);
}
#endif
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

- (void)waitForAuthGlobalWorkQueueDrain {
  dispatch_semaphore_t workerSemaphore = dispatch_semaphore_create(0);
  dispatch_async(FIRAuthGlobalWorkQueue(), ^{
    dispatch_semaphore_signal(workerSemaphore);
  });
  dispatch_semaphore_wait(workerSemaphore,
                          DISPATCH_TIME_FOREVER /*DISPATCH_TIME_NOW + 10 * NSEC_PER_SEC*/);
}

@end
#endif
#endif

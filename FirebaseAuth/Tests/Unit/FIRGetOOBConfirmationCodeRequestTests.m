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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRActionCodeSettings.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/getOobConfirmationCode?key=APIKey";

/** @var kRequestTypeKey
    @brief The name of the required "requestType" property in the request.
 */
static NSString *const kRequestTypeKey = @"requestType";

/** @var kPasswordResetRequestTypeValue
    @brief The value for the "PASSWORD_RESET" request type.
 */
static NSString *const kPasswordResetRequestTypeValue = @"PASSWORD_RESET";

/** @var kVerifyEmailRequestTypeValue
    @brief The value for the "VERIFY_EMAIL" request type.
 */
static NSString *const kVerifyEmailRequestTypeValue = @"VERIFY_EMAIL";

/** @var kEmailLinkSignInTypeValue
    @brief The value for the "EMAIL_SIGNIN" request type.
 */
static NSString *const kEmailLinkSignInTypeValue = @"EMAIL_SIGNIN";

/** @var kEmailKey
    @brief The name of the "email" property in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kTestEmail
    @brief Testing user email adadress.
 */
static NSString *const kTestEmail = @"test@gmail.com";

/** @var kAccessTokenKey
    @brief The name of the "accessToken" property in the request.
 */
static NSString *const kAccessTokenKey = @"idToken";

/** @var kTestAccessToken
    @brief Testing access token.
 */
static NSString *const kTestAccessToken = @"ACCESS_TOKEN";

/** @var kIosBundleID
    @brief Fake iOS bundle ID for testing.
 */
static NSString *const kIosBundleID = @"testBundleID";

/** @var kAndroidPackageName
    @brief Fake android package name for testing.
 */
static NSString *const kAndroidPackageName = @"adroidpackagename";

/** @var kContinueURL
    @brief Fake string value of continue url.
 */
static NSString *const kContinueURL = @"continueURL";

/** @var kAndroidMinimumVersion
    @brief Fake android minimum version for testing.
 */
static NSString *const kAndroidMinimumVersion = @"3.0";

/** @var kContinueURLKey
    @brief The key for the "continue URL" value in the request.
 */
static NSString *const kContinueURLKey = @"continueUrl";

/** @var kIosBundeIDKey
    @brief The key for the "iOS Bundle Identifier" value in the request.
 */
static NSString *const kIosBundleIDKey = @"iOSBundleId";

/** @var kAndroidPackageNameKey
    @brief The key for the "Android Package Name" value in the request.
 */
static NSString *const kAndroidPackageNameKey = @"androidPackageName";

/** @var kAndroidInstallAppKey
    @brief The key for the request parameter indicating whether the android app should be installed
        or not.
 */
static NSString *const kAndroidInstallAppKey = @"androidInstallApp";

/** @var kAndroidMinimumVersionKey
    @brief The key for the "minimum Android version supported" value in the request.
 */
static NSString *const kAndroidMinimumVersionKey = @"androidMinimumVersion";

/** @var kCanHandleCodeInAppKey
    @brief The key for the request parameter indicating whether the action code can be handled in
        the app or not.
 */
static NSString *const kCanHandleCodeInAppKey = @"canHandleCodeInApp";

/** @var kDynamicLinkDomainKey
    @brief The key for the "dynamic link domain" value in the request.
 */
static NSString *const kDynamicLinkDomainKey = @"dynamicLinkDomain";

/** @var kDynamicLinkDomain
    @brief Fake dynamic link domain for testing.
 */
static NSString *const kDynamicLinkDomain = @"test.page.link";

/** @class FIRGetOOBConfirmationCodeRequestTests
    @brief Tests for @c FIRGetOOBConfirmationCodeRequest.
 */

@interface FIRGetOOBConfirmationCodeRequestTests : XCTestCase
@end
@implementation FIRGetOOBConfirmationCodeRequestTests {
  /** @var _RPCIssuer
     @brief This backend RPC issuer is used to fake network responses for each test in the suite.
         In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
  */
  FIRFakeBackendRPCIssuer *_RPCIssuer;

  /** @var _requestConfiguration
      @brief This is the request configuration used for testing.
   */
  FIRAuthRequestConfiguration *_requestConfiguration;
}

- (void)setUp {
  [super setUp];
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
}

- (void)tearDown {
  _requestConfiguration = nil;
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testPasswordResetRequest
    @brief Tests the encoding of a password reset request.
 */
- (void)testPasswordResetRequest {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
                                  callbackInvoked = YES;
                                  RPCResponse = response;
                                  RPCError = error;
                                }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kRequestTypeKey], kPasswordResetRequestTypeValue);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kContinueURLKey], kContinueURL);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIosBundleIDKey], kIosBundleID);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidPackageNameKey], kAndroidPackageName);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidMinimumVersionKey],
                        kAndroidMinimumVersion);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidInstallAppKey],
                        [NSNumber numberWithBool:YES]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCanHandleCodeInAppKey],
                        [NSNumber numberWithBool:YES]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDynamicLinkDomainKey], kDynamicLinkDomain);
}

/** @fn testSignInWithEmailLinkRequest
    @brief Tests the encoding of a email sign-in link request.
 */
- (void)testSignInWithEmailLinkRequest {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest signInWithEmailLinkRequest:kTestEmail
                                                actionCodeSettings:[self fakeActionCodeSettings]
                                              requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
                                  callbackInvoked = YES;
                                  RPCResponse = response;
                                  RPCError = error;
                                }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kRequestTypeKey], kEmailLinkSignInTypeValue);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kContinueURLKey], kContinueURL);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIosBundleIDKey], kIosBundleID);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidPackageNameKey], kAndroidPackageName);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidMinimumVersionKey],
                        kAndroidMinimumVersion);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidInstallAppKey],
                        [NSNumber numberWithBool:YES]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCanHandleCodeInAppKey],
                        [NSNumber numberWithBool:YES]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDynamicLinkDomainKey], kDynamicLinkDomain);
}

/** @fn testEmailVerificationRequest
    @brief Tests the encoding of an email verification request.
 */
- (void)testEmailVerificationRequest {
  FIRActionCodeSettings *testSettings = [self fakeActionCodeSettings];
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest verifyEmailRequestWithAccessToken:kTestAccessToken
                                                       actionCodeSettings:testSettings
                                                     requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
                                  callbackInvoked = YES;
                                  RPCResponse = response;
                                  RPCError = error;
                                }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAccessTokenKey], kTestAccessToken);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kRequestTypeKey], kVerifyEmailRequestTypeValue);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kContinueURLKey], kContinueURL);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIosBundleIDKey], kIosBundleID);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidPackageNameKey], kAndroidPackageName);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidMinimumVersionKey],
                        kAndroidMinimumVersion);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAndroidInstallAppKey],
                        [NSNumber numberWithBool:YES]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCanHandleCodeInAppKey],
                        [NSNumber numberWithBool:YES]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDynamicLinkDomainKey], kDynamicLinkDomain);
}

#pragma mark - Helpers

/** @fn fakeActionCodeSettings
    @brief Constructs and returns a fake instance of @c FIRActionCodeSettings for testing.
    @return An instance of @c FIRActionCodeSettings for testing.
 */
- (FIRActionCodeSettings *)fakeActionCodeSettings {
  FIRActionCodeSettings *actionCodeSettings = [[FIRActionCodeSettings alloc] init];
  [actionCodeSettings setIOSBundleID:kIosBundleID];
  [actionCodeSettings setAndroidPackageName:kAndroidPackageName
                      installIfNotAvailable:YES
                             minimumVersion:kAndroidMinimumVersion];
  actionCodeSettings.handleCodeInApp = YES;
  actionCodeSettings.URL = [NSURL URLWithString:kContinueURL];
  actionCodeSettings.dynamicLinkDomain = kDynamicLinkDomain;
  return actionCodeSettings;
}

@end

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

#import "EmailPassword/FIREmailAuthProvider.h"
#import "Facebook/FIRFacebookAuthProvider.h"
#import "Google/FIRGoogleAuthProvider.h"
#import "Phone/FIRPhoneAuthCredential_Internal.h"
#import "Phone/FIRPhoneAuthProvider.h"
#import "FIRAdditionalUserInfo.h"
#import "FIRAuth.h"
#import "FIRAuthErrorUtils.h"
#import "FIRAuthGlobalWorkQueue.h"
#import "FIRUser.h"
#import "FIRUserInfo.h"
#import "FIRAuthBackend.h"
#import "FIRGetAccountInfoRequest.h"
#import "FIRGetAccountInfoResponse.h"
#import "FIRSetAccountInfoRequest.h"
#import "FIRSetAccountInfoResponse.h"
#import "FIRVerifyAssertionResponse.h"
#import "FIRVerifyAssertionRequest.h"
#import "FIRVerifyPasswordRequest.h"
#import "FIRVerifyPasswordResponse.h"
#import "FIRVerifyPhoneNumberRequest.h"
#import "FIRVerifyPhoneNumberResponse.h"
#import "FIRApp+FIRAuthUnitTests.h"
#import "OCMStubRecorder+FIRAuthUnitTests.h"
#import <OCMock/OCMock.h>

NS_ASSUME_NONNULL_BEGIN

/** @var kAPIKey
    @brief The fake API key.
 */
static NSString *const kAPIKey = @"FAKE_API_KEY";

/** @var kAccessToken
    @brief The fake access token.
 */
static NSString *const kAccessToken = @"ACCESS_TOKEN";

/** @var kNewAccessToken
    @brief A new value for the fake access token.
 */
static NSString *const kNewAccessToken = @"NEW_ACCESS_TOKEN";

/** @var kAccessTokenValidInterval
    @brief The time to live for the fake access token.
 */
static const NSTimeInterval kAccessTokenTimeToLive = 60 * 60;

/** @var kRefreshToken
    @brief The fake refresh token.
 */
static NSString *const kRefreshToken = @"REFRESH_TOKEN";

/** @var kLocalID
    @brief The fake local user ID.
 */
static NSString *const kLocalID = @"LOCAL_ID";

/** @var kAnotherLocalID
    @brief The fake local ID of another user.
 */
static NSString *const kAnotherLocalID = @"ANOTHER_LOCAL_ID";

/** @var kGoogleIDToken
    @brief The fake ID token from Google Sign-In.
 */
static NSString *const kGoogleIDToken = @"GOOGLE_ID_TOKEN";

/** @var kFacebookIDToken
    @brief The fake ID token from Facebook Sign-In. Facebook provider ID token is always nil.
 */
static NSString *const kFacebookIDToken = nil;

/** @var kGoogleAccessToken
    @brief The fake access token from Google Sign-In.
 */
static NSString *const kGoogleAccessToken = @"GOOGLE_ACCESS_TOKEN";

/** @var kFacebookAccessToken
    @brief The fake access token from Facebook Sign-In.
 */
static NSString *const kFacebookAccessToken = @"FACEBOOK_ACCESS_TOKEN";

/** @var kEmail
    @brief The fake user email.
 */
static NSString *const kEmail = @"user@company.com";

/** @var kPhoneNumber
    @brief The fake user phone number.
 */
static NSString *const kPhoneNumber = @"12345658";

/** @var kTemporaryProof
    @brief The fake temporary proof.
 */
static NSString *const kTemporaryProof = @"12345658";

/** @var kNewEmail
    @brief A new value for the fake user email.
 */
static NSString *const kNewEmail = @"newuser@company.com";

/** @var kUserName
    @brief The fake user name.
 */
static NSString *const kUserName = @"User Doe";

/** @var kNewDisplayName
    @brief A new value for the fake user display name.
 */
static NSString *const kNewDisplayName = @"New User Doe";

/** @var kPhotoURL
    @brief The fake user profile image URL string.
 */
static NSString *const kPhotoURL = @"https://host.domain/image";

/** @var kNewPhotoURL
    @brief A new value for the fake user profile image URL string..
 */
static NSString *const kNewPhotoURL = @"https://host.domain/new/image";

/** @var kPassword
    @brief The fake user password.
 */
static NSString *const kPassword = @"123456";

/** @var kNewPassword
    @brief The fake new user password.
 */
static NSString *const kNewPassword = @"1234567";

/** @var kPasswordHash
    @brief The fake user password hash.
 */
static NSString *const kPasswordHash = @"UkVEQUNURUQ=";

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

/** @var kEmailDisplayName
    @brief The fake user display name for email password user.
 */
static NSString *const kEmailDisplayName = @"Email Doe";

/** @var kFacebookDisplayName
    @brief The fake user display name under Facebook Sign-In.
 */
static NSString *const kFacebookDisplayName = @"Facebook Doe";

/** @var kGooglePhotoURL
    @brief The fake user profile image URL string under Google Sign-In.
 */
static NSString *const kGooglePhotoURL = @"https://googleusercontents.com/user/profile";

/** @var kFacebookID
    @brief The fake user ID under Facebook Login.
 */
static NSString *const kFacebookID = @"FACEBOOK_ID";

/** @var kFacebookEmail
    @brief The fake user email under Facebook Login.
 */
static NSString *const kFacebookEmail = @"user@facebook.com";

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

/** @class FIRUserTests
    @brief Tests for @c FIRUser .
 */
@interface FIRUserTests : XCTestCase
@end
@implementation FIRUserTests {

  /** @var _mockBackend
      @brief The mock @c FIRAuthBackendImplementation .
   */
  id _mockBackend;
}

/** @fn googleProfile
    @brief The fake user profile under additional user data in @c FIRVerifyAssertionResponse.
 */
+ (NSDictionary *)googleProfile {
  static NSDictionary *kGoogleProfile = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kGoogleProfile = @{
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
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

#pragma mark - Tests

/** @fn testUserProperties
    @brief Tests properties of the @c FIRUser instance.
 */
- (void)testUserProperties {
  // Mock auth provider user info for email/password for GetAccountInfo.
  id mockPasswordUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
  OCMStub([mockPasswordUserInfo providerID]).andReturn(FIREmailAuthProviderID);
  OCMStub([mockPasswordUserInfo federatedID]).andReturn(kEmail);
  OCMStub([mockPasswordUserInfo email]).andReturn(kEmail);

  // Mock auth provider user info from Google for GetAccountInfo.
  id mockGoogleUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
  OCMStub([mockGoogleUserInfo providerID]).andReturn(FIRGoogleAuthProviderID);
  OCMStub([mockGoogleUserInfo displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGoogleUserInfo photoURL]).andReturn([NSURL URLWithString:kGooglePhotoURL]);
  OCMStub([mockGoogleUserInfo federatedID]).andReturn(kGoogleID);
  OCMStub([mockGoogleUserInfo email]).andReturn(kGoogleEmail);

  // Mock auth provider user info from Facebook for GetAccountInfo.
  id mockFacebookUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
  OCMStub([mockFacebookUserInfo providerID]).andReturn(FIRFacebookAuthProviderID);
  OCMStub([mockFacebookUserInfo federatedID]).andReturn(kFacebookID);
  OCMStub([mockFacebookUserInfo email]).andReturn(kFacebookEmail);

  // Mock auth provider user info from Phone auth provider for GetAccountInfo.
  id mockPhoneUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
  OCMStub([mockPhoneUserInfo providerID]).andReturn(FIRPhoneAuthProviderID);
  OCMStub([mockPhoneUserInfo phoneNumber]).andReturn(kPhoneNumber);

  // Mock the root user info object for GetAccountInfo.
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser emailVerified]).andReturn(YES);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser photoURL]).andReturn([NSURL URLWithString:kPhotoURL]);
  OCMStub([mockGetAccountInfoResponseUser providerUserInfo])
      .andReturn((@[ mockPasswordUserInfo,
                     mockGoogleUserInfo,
                     mockFacebookUserInfo,
                     mockPhoneUserInfo ]));
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    // Verify FIRUserInfo properties on FIRUser itself.
    XCTAssertEqualObjects(user.providerID, @"Firebase");
    XCTAssertEqualObjects(user.uid, kLocalID);
    XCTAssertEqualObjects(user.displayName, kGoogleDisplayName);
    XCTAssertEqualObjects(user.photoURL, [NSURL URLWithString:kPhotoURL]);
    XCTAssertEqualObjects(user.email, kEmail);

    // Verify FIRUser properties besides providerData contents.
    XCTAssertFalse(user.anonymous);
    XCTAssertTrue(user.emailVerified);
    XCTAssertEqualObjects(user.refreshToken, kRefreshToken);
    XCTAssertEqual(user.providerData.count, 4u);

    NSDictionary<NSString *, id<FIRUserInfo>> *providerMap =
        [self dictionaryWithUserInfoArray:user.providerData];

    // Verify FIRUserInfo properties from email/password.
    id<FIRUserInfo> passwordUserInfo = providerMap[FIREmailAuthProviderID];
    XCTAssertNotNil(passwordUserInfo);
    XCTAssertEqualObjects(passwordUserInfo.uid, kEmail);
    XCTAssertNil(passwordUserInfo.displayName);
    XCTAssertNil(passwordUserInfo.photoURL);
    XCTAssertEqualObjects(passwordUserInfo.email, kEmail);

    // Verify FIRUserInfo properties from the Google auth provider.
    id<FIRUserInfo> googleUserInfo = providerMap[FIRGoogleAuthProviderID];
    XCTAssertNotNil(googleUserInfo);
    XCTAssertEqualObjects(googleUserInfo.uid, kGoogleID);
    XCTAssertEqualObjects(googleUserInfo.displayName, kGoogleDisplayName);
    XCTAssertEqualObjects(googleUserInfo.photoURL, [NSURL URLWithString:kGooglePhotoURL]);
    XCTAssertEqualObjects(googleUserInfo.email, kGoogleEmail);

    // Verify FIRUserInfo properties from the Facebook auth provider.
    id<FIRUserInfo> facebookUserInfo = providerMap[FIRFacebookAuthProviderID];
    XCTAssertNotNil(facebookUserInfo);
    XCTAssertEqualObjects(facebookUserInfo.uid, kFacebookID);
    XCTAssertNil(facebookUserInfo.displayName);
    XCTAssertNil(facebookUserInfo.photoURL);
    XCTAssertEqualObjects(facebookUserInfo.email, kFacebookEmail);

    // Verify FIRUserInfo properties from the phone auth provider.
    id<FIRUserInfo> phoneUserInfo = providerMap[FIRPhoneAuthProviderID];
    XCTAssertNotNil(phoneUserInfo);
    XCTAssertEqualObjects(phoneUserInfo.phoneNumber, kPhoneNumber);

    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateEmailSuccess
    @brief Tests the flow of a successful @c updateEmail:completion: call.
 */
- (void)testUpdateEmailSuccess {
  id (^mockUserInfoWithDisplayName)(NSString *) = ^(NSString *displayName) {
    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(displayName);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    return mockGetAccountInfoResponseUser;
  };
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  id userInfoResponse = mockUserInfoWithDisplayName(kGoogleDisplayName);
  [self signInWithEmailPasswordWithMockUserInfoResponse:userInfoResponse
                                             completion:^(FIRUser *user) {
    // Pretend that the display name on the server has been changed since last request.
    [self
        expectGetAccountInfoWithMockUserInfoResponse:mockUserInfoWithDisplayName(kNewDisplayName)];
    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                         FIRSetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      XCTAssertEqualObjects(request.email, kNewEmail);
      XCTAssertNil(request.localID);
      XCTAssertNil(request.displayName);
      XCTAssertNil(request.photoURL);
      XCTAssertNil(request.password);
      XCTAssertNil(request.providers);
      XCTAssertNil(request.deleteAttributes);
      XCTAssertNil(request.deleteProviders);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
        OCMStub([mockSetAccountInfoResponse email]).andReturn(kNewEmail);
        OCMStub([mockSetAccountInfoResponse displayName]).andReturn(kNewDisplayName);
        callback(mockSetAccountInfoResponse, nil);
      });
    });
    [user updateEmail:kNewEmail completion:^(NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(user.email, kNewEmail);
      XCTAssertEqualObjects(user.displayName, kNewDisplayName);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateEmailFailure
    @brief Tests the flow of a failed @c updateEmail:completion: call.
 */
- (void)testUpdateEmailFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andDispatchError2([FIRAuthErrorUtils invalidEmailErrorWithMessage:nil]);
    [user updateEmail:kNewEmail completion:^(NSError *_Nullable error) {
      XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidEmail);
      // Email should not have changed on the client side.
      XCTAssertEqualObjects(user.email, kEmail);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdatePhoneSuccess
    @brief Tests the flow of a successful @c updatePhoneNumberCredential:completion: call.
 */
- (void)testUpdatePhoneSuccess {
  id (^mockUserInfoWithPhoneNumber)(NSString *) = ^(NSString *phoneNumber) {
    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    if (phoneNumber.length) {
      OCMStub([mockGetAccountInfoResponseUser phoneNumber]).andReturn(phoneNumber);
    }
    return mockGetAccountInfoResponseUser;
  };

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  id userInfoResponse = mockUserInfoWithPhoneNumber(nil);
  [self signInWithEmailPasswordWithMockUserInfoResponse:userInfoResponse
                                             completion:^(FIRUser *user) {
    [self expectVerifyPhoneNumberRequestWithPhoneNumber:kPhoneNumber error:nil];
    id userInfoResponseUpdate = mockUserInfoWithPhoneNumber(kPhoneNumber);
    [self expectGetAccountInfoWithMockUserInfoResponse:userInfoResponseUpdate];

    FIRPhoneAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                   verificationCode:kVerificationCode];
    [user updatePhoneNumberCredential:credential
                           completion:^(NSError * _Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects([FIRAuth auth].currentUser.phoneNumber, kPhoneNumber);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdatePhoneNumberFailure
    @brief Tests the flow of a failed @c updatePhoneNumberCredential:completion: call.
 */
- (void)testUpdatePhoneNumberFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    OCMExpect([_mockBackend verifyPhoneNumber:[OCMArg any] callback:[OCMArg any]])
        .andDispatchError2([FIRAuthErrorUtils invalidPhoneNumberErrorWithMessage:nil]);
    FIRPhoneAuthCredential *credential =
        [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                     verificationCode:kVerificationCode];
    [user updatePhoneNumberCredential:credential completion:^(NSError *_Nullable error) {
      XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidPhoneNumber);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdatePasswordSuccess
    @brief Tests the flow of a successful @c updatePassword:completion: call.
 */
- (void)testUpdatePasswordSuccess {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                         FIRSetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      XCTAssertEqualObjects(request.password, kNewPassword);
      XCTAssertNil(request.localID);
      XCTAssertNil(request.displayName);
      XCTAssertNil(request.photoURL);
      XCTAssertNil(request.email);
      XCTAssertNil(request.providers);
      XCTAssertNil(request.deleteAttributes);
      XCTAssertNil(request.deleteProviders);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
        OCMStub([mockSetAccountInfoResponse displayName]).andReturn(kNewDisplayName);
        callback(mockSetAccountInfoResponse, nil);
      });
    });
    [user updatePassword:kNewPassword completion:^(NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertFalse(user.isAnonymous);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdatePasswordFailure
    @brief Tests the flow of a failed @c updatePassword:completion: call.
 */
- (void)testUpdatePasswordFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andDispatchError2([FIRAuthErrorUtils userDisabledErrorWithMessage:nil]);
    [user updatePassword:kNewPassword completion:^(NSError *_Nullable error) {
      XCTAssertEqual(error.code, FIRAuthErrorCodeUserDisabled);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUpdateEmptyPasswordFailure
    @brief Tests the flow of a failed @c updatePassword:completion: call due to an empty password.
 */
- (void)testUpdateEmptyPasswordFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    [user updatePassword:@"" completion:^(NSError *_Nullable error) {
      XCTAssertEqual(error.code, FIRAuthErrorCodeWeakPassword);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testChangeProfileSuccess
    @brief Tests a successful user profile change flow.
 */
- (void)testChangeProfileSuccess {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser photoURL]).andReturn(kPhotoURL);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                         FIRSetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      XCTAssertEqualObjects(request.displayName, kNewDisplayName);
      XCTAssertEqualObjects(request.photoURL, [NSURL URLWithString:kNewPhotoURL]);
      XCTAssertNil(request.localID);
      XCTAssertNil(request.email);
      XCTAssertNil(request.password);
      XCTAssertNil(request.providers);
      XCTAssertNil(request.deleteAttributes);
      XCTAssertNil(request.deleteProviders);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
        OCMStub([mockSetAccountInfoResponse displayName]).andReturn(kNewDisplayName);
        callback(mockSetAccountInfoResponse, nil);
      });
    });
    FIRUserProfileChangeRequest *profileChange = [user profileChangeRequest];
    profileChange.photoURL = [NSURL URLWithString:kNewPhotoURL];
    profileChange.displayName = kNewDisplayName;
    [profileChange commitChangesWithCompletion:^(NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(user.displayName, kNewDisplayName);
      XCTAssertEqualObjects(user.photoURL, [NSURL URLWithString:kNewPhotoURL]);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testChangeProfileFailure
    @brief Tests a failed user profile change flow.
 */
- (void)testChangeProfileFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andDispatchError2([FIRAuthErrorUtils tooManyRequestsErrorWithMessage:nil]);
    FIRUserProfileChangeRequest *profileChange = [user profileChangeRequest];
    profileChange.displayName = kNewDisplayName;
    [profileChange commitChangesWithCompletion:^(NSError *_Nullable error) {
      XCTAssertEqual(error.code, FIRAuthErrorCodeTooManyRequests);
      XCTAssertEqualObjects(user.displayName, kGoogleDisplayName);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testReloadSuccess
    @brief Tests the flow of a successful @c reloadWithCompletion: call.
 */
- (void)testReloadSuccess {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    id mockGetAccountInfoResponseUserNew = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUserNew localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUserNew email]).andReturn(kNewEmail);
    OCMStub([mockGetAccountInfoResponseUserNew displayName]).andReturn(kNewDisplayName);
    OCMStub([mockGetAccountInfoResponseUserNew passwordHash]).andReturn(kPasswordHash);
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUserNew];
    [user reloadWithCompletion:^(NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(user.email, kNewEmail);
      XCTAssertEqualObjects(user.displayName, kNewDisplayName);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testReloadFailure
    @brief Tests the flow of a failed @c reloadWithCompletion: call.
 */
- (void)testReloadFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andDispatchError2([FIRAuthErrorUtils userTokenExpiredErrorWithMessage:nil]);
    [user reloadWithCompletion:^(NSError *_Nullable error) {
      XCTAssertEqual(error.code, FIRAuthErrorCodeUserTokenExpired);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testReauthenticateSuccess
    @brief Tests the flow of a successful @c reauthenticateWithCredential:completion: call.
 */
- (void)testReauthenticateSuccess {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                         FIRVerifyPasswordResponseCallback callback) {
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockVeriyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
        // New authentication comes back with new access token.
        OCMStub([mockVeriyPasswordResponse IDToken]).andReturn(kNewAccessToken);
        OCMStub([mockVeriyPasswordResponse approximateExpirationDate])
            .andReturn([NSDate dateWithTimeIntervalSinceNow:kAccessTokenTimeToLive]);
        OCMStub([mockVeriyPasswordResponse refreshToken]).andReturn(kRefreshToken);
            callback(mockVeriyPasswordResponse, nil);
      });
    });
    OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                         FIRGetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      // Verify that the new access token is being used for subsequent requests.
      XCTAssertEqualObjects(request.accessToken, kNewAccessToken);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
        OCMStub([mockGetAccountInfoResponse users]).andReturn(@[ mockGetAccountInfoResponseUser ]);
        callback(mockGetAccountInfoResponse, nil);
      });
    });
    FIRAuthCredential *emailCredential =
        [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
    [user reauthenticateWithCredential:emailCredential completion:^(NSError *_Nullable error) {
      XCTAssertNil(error);
      // Verify that the current user is unchanged.
      XCTAssertEqual([FIRAuth auth].currentUser, user);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testReauthenticateAndRetrieveDataSuccess
    @brief Tests the flow of a successful @c reauthenticateAndRetrieveDataWithCredential:completion:
        call.
 */
- (void)testReauthenticateAndRetrieveDataSuccess {
  [self expectVerifyAssertionRequest:FIRGoogleAuthProviderID
                         federatedID:kGoogleID
                         displayName:kGoogleDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kGoogleIDToken
                 providerAccessToken:kGoogleAccessToken];

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
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRGoogleAuthProviderID);
    XCTAssertNil(error);

    [self expectVerifyAssertionRequest:FIRGoogleAuthProviderID
                           federatedID:kGoogleID
                           displayName:kGoogleDisplayName
                               profile:[[self class] googleProfile]
                       providerIDToken:kGoogleIDToken
                   providerAccessToken:kGoogleAccessToken];

    FIRAuthCredential *reauthenticateGoogleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
    [authResult.user
        reauthenticateAndRetrieveDataWithCredential:reauthenticateGoogleCredential
                                         completion:^(FIRAuthDataResult *_Nullable
                                                          reauthenticateAuthResult,
                                                      NSError *_Nullable error) {
      XCTAssertNil(error);
      // Verify that the current user is unchanged.
      XCTAssertEqual([FIRAuth auth].currentUser, authResult.user);
      // Verify that the current user and reauthenticated user are not same pointers.
      XCTAssertNotEqualObjects(authResult.user, reauthenticateAuthResult.user);
      // Verify that anyway the current user and reauthenticated user have same IDs.
      XCTAssertEqualObjects(authResult.user.uid, reauthenticateAuthResult.user.uid);
      XCTAssertEqualObjects(authResult.user.displayName, reauthenticateAuthResult.user.displayName);
      XCTAssertEqualObjects(reauthenticateAuthResult.additionalUserInfo.profile,
                            [[self class] googleProfile]);
      XCTAssertEqualObjects(reauthenticateAuthResult.additionalUserInfo.username, kUserName);
      XCTAssertEqualObjects(reauthenticateAuthResult.additionalUserInfo.providerID,
                            FIRGoogleAuthProviderID);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testReauthenticateFailure
    @brief Tests the flow of a failed @c reauthenticateWithCredential:completion: call.
 */
- (void)testReauthenticateFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                         FIRVerifyPasswordResponseCallback callback) {
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockVeriyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
        OCMStub([mockVeriyPasswordResponse IDToken]).andReturn(kNewAccessToken);
        OCMStub([mockVeriyPasswordResponse approximateExpirationDate])
            .andReturn([NSDate dateWithTimeIntervalSinceNow:kAccessTokenTimeToLive]);
        OCMStub([mockVeriyPasswordResponse refreshToken]).andReturn(kRefreshToken);
            callback(mockVeriyPasswordResponse, nil);
      });
    });
    OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                         FIRGetAccountInfoResponseCallback callback) {
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockGetAccountInfoResponseUserNew = OCMClassMock([FIRGetAccountInfoResponseUser class]);
        // The newly-signed-in user has a different ID.
        OCMStub([mockGetAccountInfoResponseUserNew localID]).andReturn(kAnotherLocalID);
        OCMStub([mockGetAccountInfoResponseUserNew email]).andReturn(kNewEmail);
        OCMStub([mockGetAccountInfoResponseUserNew displayName]).andReturn(kNewDisplayName);
        OCMStub([mockGetAccountInfoResponseUserNew passwordHash]).andReturn(kPasswordHash);
        id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
        OCMStub([mockGetAccountInfoResponse users])
            .andReturn(@[ mockGetAccountInfoResponseUserNew ]);
        callback(mockGetAccountInfoResponse, nil);
      });
    });
    FIRAuthCredential *emailCredential =
        [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
    [user reauthenticateWithCredential:emailCredential completion:^(NSError *_Nullable error) {
      // Verify user mismatch error.
      XCTAssertEqual(error.code, FIRAuthErrorCodeUserMismatch);
      // Verify that the current user is unchanged.
      XCTAssertEqual([FIRAuth auth].currentUser, user);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testReauthenticateUserMismatchFailure
    @brief Tests the flow of a failed @c reauthenticateWithCredential:completion: call due to trying
        to reauthenticate a user that does not exist.
 */
- (void)testReauthenticateUserMismatchFailure {
  id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
  OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
  OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
  OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kGoogleDisplayName);
  OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [self signInWithEmailPasswordWithMockUserInfoResponse:mockGetAccountInfoResponseUser
                                             completion:^(FIRUser *user) {
    OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                         FIRVerifyAssertionResponseCallback callback) {
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
            callback(nil, [FIRAuthErrorUtils userNotFoundErrorWithMessage:nil]);
      });
    });
    FIRAuthCredential *googleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
    [user reauthenticateWithCredential:googleCredential completion:^(NSError *_Nullable error) {
      // Verify user mismatch error.
      XCTAssertEqual(error.code, FIRAuthErrorCodeUserMismatch);
      // Verify that the current user is unchanged.
      XCTAssertEqual([FIRAuth auth].currentUser, user);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkAndRetrieveDataSuccess
    @brief Tests the flow of a successful @c linkAndRetrieveDataWithCredential:completion:
        call.
 */
- (void)testlinkAndRetrieveDataSuccess {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    [self expectVerifyAssertionRequest:FIRGoogleAuthProviderID
                           federatedID:kGoogleID
                           displayName:kGoogleDisplayName
                               profile:[[self class] googleProfile]
                       providerIDToken:kGoogleIDToken
                   providerAccessToken:kGoogleAccessToken];

    FIRAuthCredential *linkGoogleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
    [authResult.user linkAndRetrieveDataWithCredential:linkGoogleCredential
                                            completion:^(FIRAuthDataResult *_Nullable
                                                            linkAuthResult,
                                                         NSError *_Nullable error) {
      XCTAssertNil(error);
      // Verify that the current user is unchanged.
      XCTAssertEqual([FIRAuth auth].currentUser, authResult.user);
      // Verify that the current user and reauthenticated user are same pointers.
      XCTAssertEqualObjects(authResult.user, linkAuthResult.user);
      // Verify that anyway the current user and linked user have same IDs.
      XCTAssertEqualObjects(authResult.user.uid, linkAuthResult.user.uid);
      XCTAssertEqualObjects(authResult.user.displayName, linkAuthResult.user.displayName);
      XCTAssertEqualObjects(linkAuthResult.additionalUserInfo.profile,
                            [[self class] googleProfile]);
      XCTAssertEqualObjects(linkAuthResult.additionalUserInfo.username, kUserName);
      XCTAssertEqualObjects(linkAuthResult.additionalUserInfo.providerID,
                            FIRGoogleAuthProviderID);
      [expectation fulfill];
    }];

  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkAndRetrieveDataError
    @brief Tests the flow of an unsuccessful @c linkAndRetrieveDataWithCredential:completion:
        call with an error from the backend.
 */
- (void)testlinkAndRetrieveDataError {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
            callback(nil, [FIRAuthErrorUtils userDisabledErrorWithMessage:nil]);
      });
    });

    FIRAuthCredential *linkGoogleCredential =
        [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
    [authResult.user linkAndRetrieveDataWithCredential:linkGoogleCredential
                                            completion:^(FIRAuthDataResult *_Nullable
                                                            linkAuthResult,
                                                         NSError *_Nullable error) {
      XCTAssertNil(linkAuthResult);
      XCTAssertEqual(error.code, FIRAuthErrorCodeUserDisabled);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkAndRetrieveDataProviderAlreadyLinked
    @brief Tests the flow of an unsuccessful @c linkAndRetrieveDataWithCredential:completion:
        call with FIRAuthErrorCodeProviderAlreadyLinked, which is a client side error.
 */
- (void)testlinkAndRetrieveDataProviderAlreadyLinked {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    FIRAuthCredential *linkFacebookCredential =
        [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
    [authResult.user linkAndRetrieveDataWithCredential:linkFacebookCredential
                                            completion:^(FIRAuthDataResult *_Nullable
                                                            linkAuthResult,
                                                         NSError *_Nullable error) {
      XCTAssertNil(linkAuthResult);
      XCTAssertEqual(error.code, FIRAuthErrorCodeProviderAlreadyLinked);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkEmailAndRetrieveDataSuccess
    @brief Tests the flow of a successful @c linkAndRetrieveDataWithCredential:completion:
        invocation for email credential.
 */
- (void)testlinkEmailAndRetrieveDataSuccess {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kEmailDisplayName);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    // Get account info is expected to be invoked twice.
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];

    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                         FIRSetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      XCTAssertEqualObjects(request.password, kPassword);
      XCTAssertNil(request.localID);
      XCTAssertNil(request.displayName);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
        callback(mockSetAccountInfoResponse, nil);
      });
    });

    FIRAuthCredential *linkEmailCredential =
        [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
    [authResult.user linkAndRetrieveDataWithCredential:linkEmailCredential
                                            completion:^(FIRAuthDataResult *_Nullable
                                                             linkAuthResult,
                                                         NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(linkAuthResult.user.email, kEmail);
      XCTAssertEqualObjects(linkAuthResult.user.displayName, kEmailDisplayName);
      [expectation fulfill];
    }];

  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkEmailProviderAlreadyLinkedError
    @brief Tests the flow of an unsuccessful @c linkAndRetrieveDataWithCredential:completion:
        invocation for email credential and FIRAuthErrorCodeProviderAlreadyLinked which is a client
        side error.
 */
- (void)testlinkEmailProviderAlreadyLinkedError {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(kEmailDisplayName);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    // Get account info is expected to be invoked twice.
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];
    [self expectGetAccountInfoWithMockUserInfoResponse:mockGetAccountInfoResponseUser];

    OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                         FIRSetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      XCTAssertEqualObjects(request.password, kPassword);
      XCTAssertNil(request.localID);
      XCTAssertNil(request.displayName);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
        callback(mockSetAccountInfoResponse, nil);
      });
    });

    FIRAuthCredential *linkEmailCredential =
        [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
    [authResult.user linkAndRetrieveDataWithCredential:linkEmailCredential
                                            completion:^(FIRAuthDataResult *_Nullable
                                                             linkAuthResult,
                                                         NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(linkAuthResult.user.email, kEmail);
      XCTAssertEqualObjects(linkAuthResult.user.displayName, kEmailDisplayName);

      // Try linking same credential a second time to trigger client side error.
      [authResult.user linkAndRetrieveDataWithCredential:linkEmailCredential
                                              completion:^(FIRAuthDataResult *_Nullable
                                                              linkAuthResult,
                                                           NSError *_Nullable error) {
        XCTAssertNil(linkAuthResult);
        XCTAssertEqual(error.code, FIRAuthErrorCodeProviderAlreadyLinked);
        [expectation fulfill];
      }];
    }];

  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkEmailAndRetrieveDataError
    @brief Tests the flow of an unsuccessful @c linkAndRetrieveDataWithCredential:completion:
        invocation for email credential and an error from the backend.
 */
- (void)testlinkEmailAndRetrieveDataError {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                         FIRGetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        callback(nil, [FIRAuthErrorUtils tooManyRequestsErrorWithMessage:nil]);
      });
    });

    FIRAuthCredential *linkEmailCredential =
        [FIREmailAuthProvider credentialWithEmail:kEmail password:kPassword];
    [authResult.user linkAndRetrieveDataWithCredential:linkEmailCredential
                                            completion:^(FIRAuthDataResult *_Nullable
                                                            linkAuthResult,
                                                         NSError *_Nullable error) {
      XCTAssertNil(linkAuthResult);
      XCTAssertEqual(error.code, FIRAuthErrorCodeTooManyRequests);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkCredentialSuccess
    @brief Tests the flow of a successful @c linkWithCredential:completion: call, without additional
        IDP data.
 */
- (void)testlinkCredentialSuccess {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    [self expectVerifyAssertionRequest:FIRGoogleAuthProviderID
                           federatedID:kGoogleID
                           displayName:kGoogleDisplayName
                               profile:[[self class] googleProfile]
                       providerIDToken:kGoogleIDToken
                   providerAccessToken:kGoogleAccessToken];

    FIRAuthCredential *linkGoogleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
    [authResult.user linkWithCredential:linkGoogleCredential
                             completion:^(FIRUser *_Nullable user,
                                          NSError *_Nullable error) {
      XCTAssertNil(error);
      id<FIRUserInfo> userInfo = user.providerData.firstObject;
      XCTAssertEqual(userInfo.providerID, FIRGoogleAuthProviderID);
      XCTAssertEqual([FIRAuth auth].currentUser, authResult.user);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  [self assertUserGoogle:[FIRAuth auth].currentUser];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkCredentialError
    @brief Tests the flow of an unsuccessful @c linkWithCredential:completion: call, with an error
        from the backend.
 */
- (void)testlinkCredentialError {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
            callback(nil, [FIRAuthErrorUtils userDisabledErrorWithMessage:nil]);
      });
    });

    FIRAuthCredential *linkGoogleCredential =
      [FIRGoogleAuthProvider credentialWithIDToken:kGoogleIDToken accessToken:kGoogleAccessToken];
    [authResult.user linkWithCredential:linkGoogleCredential
                             completion:^(FIRUser *_Nullable user,
                                          NSError *_Nullable error) {
      XCTAssertNil(user);
      XCTAssertEqual(error.code, FIRAuthErrorCodeUserDisabled);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkCredentialProviderAlreadyLinkedError
    @brief Tests the flow of an unsuccessful @c linkWithCredential:completion: call, with a client
        side error.
 */
- (void)testlinkCredentialProviderAlreadyLinkedError {
  [self expectVerifyAssertionRequest:FIRFacebookAuthProviderID
                         federatedID:kFacebookID
                         displayName:kFacebookDisplayName
                             profile:[[self class] googleProfile]
                     providerIDToken:kFacebookIDToken
                 providerAccessToken:kFacebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRAuth auth] signOut:NULL];
  FIRAuthCredential *facebookCredential =
      [FIRFacebookAuthProvider credentialWithAccessToken:kFacebookAccessToken];
  [[FIRAuth auth] signInAndRetrieveDataWithCredential:facebookCredential
                                           completion:^(FIRAuthDataResult *_Nullable authResult,
                                                        NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    [self assertUserFacebook:authResult.user];
    XCTAssertEqualObjects(authResult.additionalUserInfo.profile, [[self class] googleProfile]);
    XCTAssertEqualObjects(authResult.additionalUserInfo.username, kUserName);
    XCTAssertEqualObjects(authResult.additionalUserInfo.providerID, FIRFacebookAuthProviderID);
    XCTAssertNil(error);

    FIRAuthCredential *linkFacebookCredential =
        [FIRFacebookAuthProvider credentialWithAccessToken:kGoogleAccessToken];
    [authResult.user linkWithCredential:linkFacebookCredential
                             completion:^(FIRUser *_Nullable user,
                                          NSError *_Nullable error) {
      XCTAssertNil(user);
      XCTAssertEqual(error.code, FIRAuthErrorCodeProviderAlreadyLinked);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkPhoneAuthCredentialSuccess
    @brief Tests the flow of a successful @c linkAndRetrieveDataWithCredential:completion:
        call using a phoneAuthCredential.
 */
- (void)testlinkPhoneAuthCredentialSuccess {
  id (^mockUserInfoWithPhoneNumber)(NSString *) = ^(NSString *phoneNumber) {
    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    if (phoneNumber.length) {
      NSDictionary *userInfoDictionary = @{ @"providerId" : FIRPhoneAuthProviderID };
      FIRGetAccountInfoResponseProviderUserInfo *userInfo =
          [[FIRGetAccountInfoResponseProviderUserInfo alloc] initWithDictionary:userInfoDictionary];
      OCMStub([mockGetAccountInfoResponseUser providerUserInfo]).andReturn(@[ userInfo ]);
      OCMStub([mockGetAccountInfoResponseUser phoneNumber]).andReturn(phoneNumber);
    }
    return mockGetAccountInfoResponseUser;
  };

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  id userInfoResponse = mockUserInfoWithPhoneNumber(nil);
  [self signInWithEmailPasswordWithMockUserInfoResponse:userInfoResponse
                                             completion:^(FIRUser *user) {
    [self expectVerifyPhoneNumberRequestWithPhoneNumber:kPhoneNumber error:nil];
    id userInfoResponseUpdate = mockUserInfoWithPhoneNumber(kPhoneNumber);
    [self expectGetAccountInfoWithMockUserInfoResponse:userInfoResponseUpdate];

    FIRPhoneAuthCredential *credential =
        [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                     verificationCode:kVerificationCode];
    [user linkAndRetrieveDataWithCredential:credential
                                 completion:^(FIRAuthDataResult *_Nullable
                                              linkAuthResult,
                                              NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects([FIRAuth auth].currentUser.providerData.firstObject.providerID,
                            FIRPhoneAuthProviderID);
      XCTAssertEqualObjects([FIRAuth auth].currentUser.phoneNumber, kPhoneNumber);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testUnlinkPhoneAuthCredentialSuccess
    @brief Tests the flow of a successful @c unlinkFromProvider:completion: call using a
        @c FIRPhoneAuthProvider.
 */
- (void)testUnlinkPhoneAuthCredentialSuccess {
  id (^mockUserInfoWithPhoneNumber)(NSString *) = ^(NSString *phoneNumber) {
    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    if (phoneNumber.length) {
      NSDictionary *userInfoDictionary = @{ @"providerId" : FIRPhoneAuthProviderID };
      FIRGetAccountInfoResponseProviderUserInfo *userInfo =
          [[FIRGetAccountInfoResponseProviderUserInfo alloc] initWithDictionary:userInfoDictionary];
      OCMStub([mockGetAccountInfoResponseUser providerUserInfo]).andReturn(@[ userInfo ]);
      OCMStub([mockGetAccountInfoResponseUser phoneNumber]).andReturn(phoneNumber);
    }
    return mockGetAccountInfoResponseUser;
  };

  OCMExpect([_mockBackend setAccountInfo:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRSetAccountInfoRequest *_Nullable request,
                         FIRSetAccountInfoResponseCallback callback) {
      XCTAssertEqualObjects(request.APIKey, kAPIKey);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      XCTAssertNotNil(request.deleteProviders);
      XCTAssertNil(request.email);
      XCTAssertNil(request.localID);
      XCTAssertNil(request.displayName);
      XCTAssertNil(request.photoURL);
      XCTAssertNil(request.password);
      XCTAssertNil(request.providers);
      XCTAssertNil(request.deleteAttributes);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        id mockSetAccountInfoResponse = OCMClassMock([FIRSetAccountInfoResponse class]);
        callback(mockSetAccountInfoResponse, nil);
      });
  });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  id userInfoResponse = mockUserInfoWithPhoneNumber(nil);
  [self signInWithEmailPasswordWithMockUserInfoResponse:userInfoResponse
                                             completion:^(FIRUser *user) {
    [self expectVerifyPhoneNumberRequestWithPhoneNumber:kPhoneNumber error:nil];
    id userInfoResponseUpdate = mockUserInfoWithPhoneNumber(kPhoneNumber);
    [self expectGetAccountInfoWithMockUserInfoResponse:userInfoResponseUpdate];

    FIRPhoneAuthCredential *credential =
        [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                     verificationCode:kVerificationCode];
    // Link phone credential.
    [user linkAndRetrieveDataWithCredential:credential
                                 completion:^(FIRAuthDataResult *_Nullable
                                              linkAuthResult,
                                              NSError *_Nullable error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects([FIRAuth auth].currentUser.providerData.firstObject.providerID,
                            FIRPhoneAuthProviderID);
      XCTAssertEqualObjects([FIRAuth auth].currentUser.phoneNumber, kPhoneNumber);
      // Immediately unlink the phone auth provider.
      [user unlinkFromProvider:FIRPhoneAuthProviderID
                    completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNil([FIRAuth auth].currentUser.phoneNumber);
        [expectation fulfill];
      }];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkPhoneAuthCredentialFailure
    @brief Tests the flow of a failed call to @c linkAndRetrieveDataWithCredential:completion: due
        to a phone provider already being linked.
 */
- (void)testlinkPhoneAuthCredentialFailure {
  id (^mockUserInfoWithPhoneNumber)(NSString *) = ^(NSString *phoneNumber) {
    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    if (phoneNumber.length) {
      OCMStub([mockGetAccountInfoResponseUser phoneNumber]).andReturn(phoneNumber);
    }
    return mockGetAccountInfoResponseUser;
  };

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  id userInfoResponse = mockUserInfoWithPhoneNumber(nil);
  [self signInWithEmailPasswordWithMockUserInfoResponse:userInfoResponse
                                             completion:^(FIRUser *user) {
    NSError *error = [FIRAuthErrorUtils providerAlreadyLinkedError];
    [self expectVerifyPhoneNumberRequestWithPhoneNumber:nil error:error];
    FIRPhoneAuthCredential *credential =
        [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                     verificationCode:kVerificationCode];
    [user linkAndRetrieveDataWithCredential:credential
                                 completion:^(FIRAuthDataResult *_Nullable
                                              linkAuthResult,
                                              NSError *_Nullable error) {
      XCTAssertNotNil(error);
      XCTAssertEqual(error.code, FIRAuthErrorCodeProviderAlreadyLinked);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testlinkPhoneCredentialAlreadyExistsError
    @brief Tests the flow of @c linkAndRetrieveDataWithCredential:completion:
        call using a phoneAuthCredential and a credential already exisits error. In this case we
        should get a FIRAuthCredential in the error object.
 */
- (void)testlinkPhoneCredentialAlreadyExistsError {
  id (^mockUserInfoWithPhoneNumber)(NSString *) = ^(NSString *phoneNumber) {
    id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
    OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
    OCMStub([mockGetAccountInfoResponseUser email]).andReturn(kEmail);
    OCMStub([mockGetAccountInfoResponseUser passwordHash]).andReturn(kPasswordHash);
    if (phoneNumber.length) {
      OCMStub([mockGetAccountInfoResponseUser phoneNumber]).andReturn(phoneNumber);
    }
    return mockGetAccountInfoResponseUser;
  };

   void (^expectVerifyPhoneNumberRequest)(NSString *) = ^(NSString *phoneNumber) {
    OCMExpect([_mockBackend verifyPhoneNumber:[OCMArg any] callback:[OCMArg any]])
        .andCallBlock2(^(FIRVerifyPhoneNumberRequest *_Nullable request,
                         FIRVerifyPhoneNumberResponseCallback callback) {
      XCTAssertEqualObjects(request.verificationID, kVerificationID);
      XCTAssertEqualObjects(request.verificationCode, kVerificationCode);
      XCTAssertEqualObjects(request.accessToken, kAccessToken);
      dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        FIRPhoneAuthCredential *credential =
            [[FIRPhoneAuthCredential alloc] initWithTemporaryProof:kTemporaryProof
                                                       phoneNumber:kPhoneNumber
                                                        providerID:FIRPhoneAuthProviderID];
        callback(nil,
                 [FIRAuthErrorUtils credentialAlreadyInUseErrorWithMessage:nil
                                                                credential:credential]);
      });
    });
  };

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  id userInfoResponse = mockUserInfoWithPhoneNumber(nil);
  [self signInWithEmailPasswordWithMockUserInfoResponse:userInfoResponse
                                             completion:^(FIRUser *user) {
    expectVerifyPhoneNumberRequest(kPhoneNumber);

    FIRPhoneAuthCredential *credential =
        [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kVerificationID
                                                     verificationCode:kVerificationCode];
    [user linkAndRetrieveDataWithCredential:credential
                                 completion:^(FIRAuthDataResult *_Nullable
                                              linkAuthResult,
                                              NSError *_Nullable error) {
      XCTAssertNil(linkAuthResult);
      XCTAssertEqual(error.code, FIRAuthErrorCodeCredentialAlreadyInUse);
      FIRPhoneAuthCredential *credential = error.userInfo[FIRAuthUpdatedCredentialKey];
      XCTAssertEqual(credential.temporaryProof, kTemporaryProof);
      XCTAssertEqual(credential.phoneNumber, kPhoneNumber);
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

#pragma mark - Helpers

/** @fn signInWithEmailPasswordWithMockGetAccountInfoResponse:completion:
    @brief Signs in with an email and password account with mocked backend end calls.
    @param mockUserInfoResponse A mocked FIRGetAccountInfoResponseUser object.
    @param completion The completion block that takes the newly signed-in user as the only
        parameter.
 */
- (void)signInWithEmailPasswordWithMockUserInfoResponse:(id)mockUserInfoResponse
                                     completion:(void (^)(FIRUser *user))completion {
  OCMExpect([_mockBackend verifyPassword:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPasswordRequest *_Nullable request,
                       FIRVerifyPasswordResponseCallback callback) {
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyPasswordResponse = OCMClassMock([FIRVerifyPasswordResponse class]);
      OCMStub([mockVeriyPasswordResponse IDToken]).andReturn(kAccessToken);
      OCMStub([mockVeriyPasswordResponse approximateExpirationDate])
          .andReturn([NSDate dateWithTimeIntervalSinceNow:kAccessTokenTimeToLive]);
      OCMStub([mockVeriyPasswordResponse refreshToken]).andReturn(kRefreshToken);
          callback(mockVeriyPasswordResponse, nil);
    });
  });
  [self expectGetAccountInfoWithMockUserInfoResponse:mockUserInfoResponse];
  [[FIRAuth auth] signOut:NULL];
  [[FIRAuth auth] signInWithEmail:kEmail password:kPassword completion:^(FIRUser *_Nullable user,
                                                                         NSError *_Nullable error) {
    XCTAssertNotNil(user);
    XCTAssertNil(error);
    completion(user);
  }];
}

/** @fn expectGetAccountInfoWithMockUserInfoResponse:
    @brief Expects a GetAccountInfo request on the mock backend and calls back with provided
        fake account data.
    @param mockUserInfoResponse A mock @c FIRGetAccountInfoResponseUser object containing user info.
 */
- (void)expectGetAccountInfoWithMockUserInfoResponse:(id)mockUserInfoResponse {
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.accessToken, kAccessToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
      OCMStub([mockGetAccountInfoResponse users]).andReturn(@[ mockUserInfoResponse ]);
      callback(mockGetAccountInfoResponse, nil);
    });
  });
}

/** @fn dictionaryWithUserInfoArray:
    @brief Converts an array of @c FIRUserInfo into a dictionary that indexed by provider IDs.
    @param userInfoArray An array of @c FIRUserInfo objects.
    @return A dictionary contains same values as @c userInfoArray does but keyed by their
        @c providerID .
 */
- (NSDictionary<NSString *, id<FIRUserInfo>> *)
    dictionaryWithUserInfoArray:(NSArray<id<FIRUserInfo>> *)userInfoArray {
  NSMutableDictionary<NSString *, id<FIRUserInfo>> *map =
      [NSMutableDictionary dictionaryWithCapacity:userInfoArray.count];
  for (id<FIRUserInfo> userInfo in userInfoArray) {
    XCTAssertNil(map[userInfo.providerID]);
    map[userInfo.providerID] = userInfo;
  }
  return map;
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

/** @fn assertUserGoogle
    @brief Asserts the given FIRUser matching the fake data returned by
        @c expectGetAccountInfo:federatedID:displayName: .
    @param user The user object to be verified.
 */
- (void)assertUserGoogle:(FIRUser *)user {
  XCTAssertNotNil(user);
  XCTAssertEqualObjects(user.uid, kLocalID);
  XCTAssertEqualObjects(user.displayName, kGoogleDisplayName);
  XCTAssertEqual(user.providerData.count, 1u);
  id<FIRUserInfo> googleUserInfo = user.providerData[0];
  XCTAssertEqualObjects(googleUserInfo.providerID, FIRGoogleAuthProviderID);
  XCTAssertEqualObjects(googleUserInfo.uid, kGoogleID);
  XCTAssertEqualObjects(googleUserInfo.displayName, kGoogleDisplayName);
  XCTAssertEqualObjects(googleUserInfo.email, kGoogleEmail);
}

/** @fn assertUserFacebook
    @brief Asserts the given FIRUser matching the fake data returned by
        @c expectGetAccountInfo:federatedID:displayName: .
    @param user The user object to be verified.
 */
- (void)assertUserFacebook:(FIRUser *)user {
  XCTAssertNotNil(user);
  XCTAssertEqualObjects(user.uid, kLocalID);
  XCTAssertEqualObjects(user.displayName, kFacebookDisplayName);
  XCTAssertEqual(user.providerData.count, 1u);
  id<FIRUserInfo> googleUserInfo = user.providerData[0];
  XCTAssertEqualObjects(googleUserInfo.providerID, FIRFacebookAuthProviderID);
  XCTAssertEqualObjects(googleUserInfo.uid, kFacebookID);
  XCTAssertEqualObjects(googleUserInfo.displayName, kFacebookDisplayName);
  XCTAssertEqualObjects(googleUserInfo.email, kGoogleEmail);
}

/** @fn expectGetAccountInfo:federatedID:displayName:
    @brief Expects a GetAccountInfo request on the mock backend and calls back with fake account
        data for a Google Sign-In user.
 */
- (void)expectGetAccountInfo:(NSString *)providerId
                 federatedID:(NSString *)federatedID
                 displayName:(NSString *)displayName {
  OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRGetAccountInfoRequest *_Nullable request,
                       FIRGetAccountInfoResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.accessToken, kAccessToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockGoogleUserInfo = OCMClassMock([FIRGetAccountInfoResponseProviderUserInfo class]);
      OCMStub([mockGoogleUserInfo providerID]).andReturn(providerId);
      OCMStub([mockGoogleUserInfo displayName]).andReturn(displayName);
      OCMStub([mockGoogleUserInfo federatedID]).andReturn(federatedID);
      OCMStub([mockGoogleUserInfo email]).andReturn(kGoogleEmail);
      id mockGetAccountInfoResponseUser = OCMClassMock([FIRGetAccountInfoResponseUser class]);
      OCMStub([mockGetAccountInfoResponseUser localID]).andReturn(kLocalID);
      OCMStub([mockGetAccountInfoResponseUser displayName]).andReturn(displayName);
      OCMStub([mockGetAccountInfoResponseUser providerUserInfo])
          .andReturn((@[ mockGoogleUserInfo ]));
      id mockGetAccountInfoResponse = OCMClassMock([FIRGetAccountInfoResponse class]);
      OCMStub([mockGetAccountInfoResponse users]).andReturn(@[ mockGetAccountInfoResponseUser ]);
      callback(mockGetAccountInfoResponse, nil);
    });
  });
}

/** @fn expectVerifyAssertionRequest:federatedID:displayName:profile:providerAccessToken:
    @brief Expects a Verify Assertion request on the mock backend and calls back with fake account
        data.
 */
- (void)expectVerifyAssertionRequest:(NSString *)providerId
                         federatedID:(NSString *)federatedID
                         displayName:(NSString *)displayName
                             profile:(NSDictionary *)profile
                     providerIDToken:(nullable NSString *)providerIDToken
                 providerAccessToken:(NSString *)providerAccessToken {
  OCMExpect([_mockBackend verifyAssertion:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyAssertionRequest *_Nullable request,
                       FIRVerifyAssertionResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    XCTAssertEqualObjects(request.providerID, providerId);
    XCTAssertEqualObjects(request.providerIDToken, providerIDToken);
    XCTAssertEqualObjects(request.providerAccessToken, providerAccessToken);
    XCTAssertTrue(request.returnSecureToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVeriyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
      OCMStub([mockVeriyAssertionResponse federatedID]).andReturn(federatedID);
      OCMStub([mockVeriyAssertionResponse providerID]).andReturn(providerId);
      OCMStub([mockVeriyAssertionResponse localID]).andReturn(kLocalID);
      OCMStub([mockVeriyAssertionResponse displayName]).andReturn(displayName);
      OCMStub([mockVeriyAssertionResponse profile]).andReturn(profile);
      OCMStub([mockVeriyAssertionResponse username]).andReturn(kUserName);
      [self stubTokensWithMockResponse:mockVeriyAssertionResponse];
      callback(mockVeriyAssertionResponse, nil);
    });
  });
  [self expectGetAccountInfo:providerId federatedID:federatedID displayName:displayName];
}

/** @fn expectVerifyPhoneNumberRequestWithPhoneNumber:error:
    @brief Expects a verify phone numner request on the mock backend and calls back with fake
        account data or an error.
    @param phoneNumber Optionally; The phone number to use in the mocked response.
    @param error Optionally; The error to return in the mocked response.
 */
- (void)expectVerifyPhoneNumberRequestWithPhoneNumber:(nullable NSString *)phoneNumber
                                                error:(nullable NSError*)error {
  OCMExpect([_mockBackend verifyPhoneNumber:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyPhoneNumberRequest *_Nullable request,
                     FIRVerifyPhoneNumberResponseCallback callback) {
    XCTAssertEqualObjects(request.verificationID, kVerificationID);
    XCTAssertEqualObjects(request.verificationCode, kVerificationCode);
    XCTAssertEqualObjects(request.accessToken, kAccessToken);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      if (error) {
        callback(nil, error);
        return;
      }
      id mockVerifyPhoneNumberResponse = OCMClassMock([FIRVerifyPhoneNumberResponse class]);
      OCMStub([mockVerifyPhoneNumberResponse phoneNumber]).andReturn(phoneNumber);
      callback(mockVerifyPhoneNumberResponse, nil);
    });
  });
}

@end

NS_ASSUME_NONNULL_END

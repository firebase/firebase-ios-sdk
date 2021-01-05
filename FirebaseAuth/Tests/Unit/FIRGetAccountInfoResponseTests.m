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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetAccountInfoRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetAccountInfoResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthInternalErrors.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kUsersKey
    @brief the name of the "users" property in the response.
 */
static NSString *const kUsersKey = @"users";

/** @var kVerifiedProviderKey
    @brief The name of the "VerifiedProvider" property in the response.
 */
static NSString *const kProviderUserInfoKey = @"providerUserInfo";

/** @var kPhotoUrlKey
    @brief The name of the "photoURL" property in the response.
 */
static NSString *const kPhotoUrlKey = @"photoUrl";

/** @var kTestPhotoURL
    @brief The fake photoUrl property value in the response.
 */
static NSString *const kTestPhotoURL = @"testPhotoURL";

/** @var kTestAccessToken
    @brief testing token.
 */
static NSString *const kTestAccessToken = @"testAccessToken";

/** @var kProviderIDkey
    @brief The name of the "provider ID" property in the response.
 */
static NSString *const kProviderIDkey = @"providerId";

/** @var kTestProviderID
    @brief The fake providerID property value in the response.
 */
static NSString *const kTestProviderID = @"testProviderID";

/** @var kDisplayNameKey
    @brief The name of the "Display Name" property in the response.
 */
static NSString *const kDisplayNameKey = @"displayName";

/** @var kTestDisplayName
    @brief The fake DisplayName property value in the response.
 */
static NSString *const kTestDisplayName = @"DisplayName";

/** @var kFederatedIDKey
    @brief The name of the "federated Id" property in the response.
 */
static NSString *const kFederatedIDKey = @"federatedId";

/** @var kTestFederatedID
    @brief The fake federated Id property value in the response.
 */
static NSString *const kTestFederatedID = @"testFederatedId";

/** @var kEmailKey
    @brief The name of the "Email" property in the response.
 */
static NSString *const kEmailKey = @"email";

/** @var kTestEmail
    @brief The fake email property value in the response.
 */
static NSString *const kTestEmail = @"testEmail";

/** @var kPasswordHashKey
    @brief The name of the "password hash" property in the response.
 */
static NSString *const kPasswordHashKey = @"passwordHash";

/** @var kTestPasswordHash
    @brief The fake password hash property value in the response.
 */
static NSString *const kTestPasswordHash = @"testPasswordHash";

/** @var kLocalIDKey
    @brief The key for the "localID" value in the response.
 */
static NSString *const kLocalIDKey = @"localId";

/** @var kTestLocalID
    @brief The fake @c localID for testing in the response.
 */
static NSString *const kTestLocalID = @"testLocalId";

/** @var kEmailVerifiedKey
    @brief The key for the "emailVerified" value in the response.
 */
static NSString *const kEmailVerifiedKey = @"emailVerified";

/** @class FIRGetAccountInfoResponseTests
    @brief Tests for @c FIRGetAccountInfoResponse.
 */
@interface FIRGetAccountInfoResponseTests : XCTestCase
@end
@implementation FIRGetAccountInfoResponseTests {
  /** @var _RPCIssuer
      @brief This backend RPC issuer is used to fake network responses for each test in the suite.
          In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;
}

- (void)setUp {
  [super setUp];
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
}

- (void)tearDown {
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testGetAccountInfoUnexpectedResponseError
    @brief This test simulates an unexpected response returned from server in @c GetAccountInfo
        flow.
 */
- (void)testGetAccountInfoUnexpectedResponseError {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRGetAccountInfoRequest *request =
      [[FIRGetAccountInfoRequest alloc] initWithAccessToken:kTestAccessToken
                                       requestConfiguration:requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      getAccountInfo:request
            callback:^(FIRGetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  NSArray *erroneousUserData = @[ @"user1Data", @"user2Data" ];
  [_RPCIssuer respondWithJSON:@{kUsersKey : erroneousUserData}];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqualObjects(RPCError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInternalError);
  XCTAssertNotNil(RPCError.userInfo[NSUnderlyingErrorKey]);
  NSError *underlyingError = RPCError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertNotNil(underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey]);
  XCTAssertNil(RPCResponse);
}

/** @fn testSuccessfulGetAccountInfoResponse
    @brief This test simulates a successful @c GetAccountInfo flow.
 */
- (void)testSuccessfulGetAccountInfoResponse {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRGetAccountInfoRequest *request =
      [[FIRGetAccountInfoRequest alloc] initWithAccessToken:kTestAccessToken
                                       requestConfiguration:requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      getAccountInfo:request
            callback:^(FIRGetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  NSArray *users = @[ @{
    kProviderUserInfoKey : @[ @{
      kProviderIDkey : kTestProviderID,
      kDisplayNameKey : kTestDisplayName,
      kPhotoUrlKey : kTestPhotoURL,
      kFederatedIDKey : kTestFederatedID,
      kEmailKey : kTestEmail,
    } ],
    kLocalIDKey : kTestLocalID,
    kDisplayNameKey : kTestDisplayName,
    kEmailKey : kTestEmail,
    kPhotoUrlKey : kTestPhotoURL,
    kEmailVerifiedKey : @YES,
    kPasswordHashKey : kTestPasswordHash
  } ];
  [_RPCIssuer respondWithJSON:@{
    @"users" : users,
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertNotNil(RPCResponse.users);
  if ([RPCResponse.users count]) {
    NSURL *responsePhotoUrl = RPCResponse.users[0].photoURL;
    XCTAssertEqualObjects(responsePhotoUrl.absoluteString, kTestPhotoURL);
    XCTAssertEqualObjects(RPCResponse.users[0].displayName, kTestDisplayName);
    XCTAssertEqualObjects(RPCResponse.users[0].email, kTestEmail);
    XCTAssertEqualObjects(RPCResponse.users[0].localID, kTestLocalID);
    XCTAssertEqual(RPCResponse.users[0].emailVerified, YES);
    XCTAssertEqualObjects(RPCResponse.users[0].passwordHash, kTestPasswordHash);
    NSArray<FIRGetAccountInfoResponseProviderUserInfo *> *providerUserInfo =
        RPCResponse.users[0].providerUserInfo;
    if ([providerUserInfo count]) {
      NSURL *providerInfoPhotoUrl = providerUserInfo[0].photoURL;
      XCTAssertEqualObjects(providerInfoPhotoUrl.absoluteString, kTestPhotoURL);
      XCTAssertEqualObjects(providerUserInfo[0].providerID, kTestProviderID);
      XCTAssertEqualObjects(providerUserInfo[0].displayName, kTestDisplayName);
      XCTAssertEqualObjects(providerUserInfo[0].federatedID, kTestFederatedID);
      XCTAssertEqualObjects(providerUserInfo[0].email, kTestEmail);
    }
  }
}

@end

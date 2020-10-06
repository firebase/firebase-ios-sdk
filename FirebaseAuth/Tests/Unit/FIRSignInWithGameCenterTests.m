/*
 * Copyright 2018 Google
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

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignInWithGameCenterRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignInWithGameCenterResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKEY";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/signInWithGameCenter?key=APIKEY";

/** @var kIDTokenKey
    @brief The key of the id token.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kIDToken
    @brief The testing id token.
 */
static NSString *const kIDToken = @"IDTOKEN";

/** @var kRefreshTokenKey
    @brief The key of the refresh token.
 */
static NSString *const kRefreshTokenKey = @"refreshToken";

/** @var kRefreshToken
    @brief The testing refresh token.
 */
static NSString *const kRefreshToken = @"PUBLICKEYURL";

/** @var kLocalIDKey
    @brief The key of local id.
 */
static NSString *const kLocalIDKey = @"localId";

/** @var kLocalID
    @brief The testing local id.
 */
static NSString *const kLocalID = @"LOCALID";

/** @var kPlayerIDKey
    @brief The key of player id.
 */
static NSString *const kPlayerIDKey = @"playerId";

/** @var kPlayerID
    @brief The testing player id.
 */
static NSString *const kPlayerID = @"PLAYERID";

/** @var kApproximateExpirationDateKey
    @brief The approximate expiration date key.
 */
static NSString *const kApproximateExpirationDateKey = @"expiresIn";

/** @var kApproximateExpirationDate
    @brief The testing approximate expration date.
 */
static NSString *const kApproximateExpirationDate = @"3600";

/** @var kIsNewUserKey
    @brief The key of whether the user is new user.
 */
static NSString *const kIsNewUserKey = @"isNewUser";

/** @var kIsNewUser
    @brief The testing isNewUser.
 */
static BOOL const kIsNewUser = YES;

/** @var kDisplayNameKey
    @brief The key of display name.
 */
static NSString *const kDisplayNameKey = @"displayName";

/** @var kDisplayName
    @brief The testing display name.
 */
static NSString *const kDisplayName = @"DISPLAYNAME";

/** @var kPublicKeyURLKey
    @brief The key of public key url.
 */
static NSString *const kPublicKeyURLKey = @"publicKeyUrl";

/** @var kPublicKeyURL
    @brief The testing public key url.
 */
static NSString *const kPublicKeyURL = @"PUBLICKEYURL";

/** @var kSignatureKey
    @brief The key of the signature.
 */
static NSString *const kSignatureKey = @"signature";

/** @var kSignature
    @brief The testing signature.
 */
static NSString *const kSignature = @"AAAABBBBCCCC";

/** @var kSaltKey
    @brief The key of the salt.
 */
static NSString *const kSaltKey = @"salt";

/** @var kSalt
    @brief The testing salt.
 */
static NSString *const kSalt = @"AAAA";

/** @var kTimestampKey
    @brief The key of the timestamp.
 */
static NSString *const kTimestampKey = @"timestamp";

/** @var kTimestamp
    @brief The testing timestamp.
 */
static uint64_t const kTimestamp = 12345678;

/** @var kAccessTokenKey
    @brief The key of the access token.
 */
static NSString *const kAccessTokenKey = @"idToken";

/** @var kAccessToken
    @brief The testing access token.
 */
static NSString *const kAccessToken = @"ACCESSTOKEN";

@interface FIRSignInWithGameCenterTests : XCTestCase

/** @property RPCIssuer
    @brief This backend RPC issuer is used to fake network responses for each test in the suite.
    In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
 */
@property(nonatomic, strong) FIRFakeBackendRPCIssuer *RPCIssuer;

/** @property requestConfiguration
    @brief This is the request configuration used for testing.
 */
@property(nonatomic, strong) FIRAuthRequestConfiguration *requestConfiguration;

@end

@implementation FIRSignInWithGameCenterTests

- (void)setUp {
  [super setUp];

  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  self.RPCIssuer = RPCIssuer;
  self.requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
}

- (void)tearDown {
  self.requestConfiguration = nil;
  self.RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];

  [super tearDown];
}

- (void)testRequestResponseEncoding {
  NSData *signature = [[NSData alloc] initWithBase64EncodedString:kSignature options:0];
  NSData *salt = [[NSData alloc] initWithBase64EncodedString:kSalt options:0];
  FIRSignInWithGameCenterRequest *request =
      [[FIRSignInWithGameCenterRequest alloc] initWithPlayerID:kPlayerID
                                                  publicKeyURL:[NSURL URLWithString:kPublicKeyURL]
                                                     signature:signature
                                                          salt:salt
                                                     timestamp:kTimestamp
                                                   displayName:kDisplayName
                                          requestConfiguration:self.requestConfiguration];
  request.accessToken = kAccessToken;

  __block BOOL callbackInvoked;
  __block FIRSignInWithGameCenterResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend signInWithGameCenter:request
                              callback:^(FIRSignInWithGameCenterResponse *_Nullable response,
                                         NSError *_Nullable error) {
                                RPCResponse = response;
                                RPCError = error;
                                callbackInvoked = YES;
                              }];

  XCTAssertEqualObjects(self.RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(self.RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kPlayerIDKey], kPlayerID);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kPublicKeyURLKey], kPublicKeyURL);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kSignatureKey], kSignature);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kSaltKey], kSalt);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kTimestampKey],
                        [NSNumber numberWithInteger:kTimestamp]);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kAccessTokenKey], kAccessToken);
  XCTAssertEqualObjects(self.RPCIssuer.decodedRequest[kDisplayNameKey], kDisplayName);

  NSDictionary *jsonDictionary = @{
    @"idToken" : kIDToken,
    @"refreshToken" : kRefreshToken,
    @"localId" : kLocalID,
    @"playerId" : kPlayerID,
    @"expiresIn" : kApproximateExpirationDate,
    @"isNewUser" : [NSNumber numberWithBool:kIsNewUser],
    @"displayName" : kDisplayName,
  };
  [self.RPCIssuer respondWithJSON:jsonDictionary];

  XCTAssertTrue(callbackInvoked);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kIDToken);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kRefreshToken);
  XCTAssertEqualObjects(RPCResponse.localID, kLocalID);
  XCTAssertEqualObjects(RPCResponse.playerID, kPlayerID);
  XCTAssertEqual(RPCResponse.isNewUser, kIsNewUser);
  XCTAssertEqualObjects(RPCResponse.displayName, kDisplayName);
}

@end

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

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestIdentifier
    @brief A test value for @c FIRCreateAuthURIRequest.identifier
 */
static NSString *const kTestIdentifier = @"identifier_value";

/** @var kTestContinueURI
    @brief A test value for @c FIRCreateAuthURIRequest.continueURI
 */
static NSString *const kTestContinueURI = @"https://www.example.com/";

/** @var kTestAPIKey
    @brief A test value for @c FIRCreateAuthURIRequest.APIKey
 */
static NSString *const kTestAPIKey = @"apikey_value";

/** @var kTestExpectedRequestURL
    @brief The URL we are expecting should be requested by valid requests.
 */
static NSString *const kTestExpectedRequestURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/createAuthUri?key=apikey_value";

/** @var kTestExpectedKind
    @brief The expected value for the "kind" parameter of a successful response.
 */
static NSString *const kTestExpectedKind = @"identitytoolkit#CreateAuthUriResponse";

/** @var kTestProviderID1
    @brief A valid value for a provider ID in the @c FIRCreateAuthURIResponse.allProviders array.
 */
static NSString *const kTestProviderID1 = @"google.com";

/** @var kTestProviderID2
    @brief A valid value for a provider ID in the @c FIRCreateAuthURIResponse.allProviders array.
 */
static NSString *const kTestProviderID2 = @"facebook.com";

/** @class FIRAuthBackendCreateAuthURITests
    @brief Unit tests for createAuthURI.
 */
@interface FIRAuthBackendCreateAuthURITests : XCTestCase
@end
@implementation FIRAuthBackendCreateAuthURITests

- (void)testRequestAndResponseEncoding {
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRCreateAuthURIRequest *request =
      [[FIRCreateAuthURIRequest alloc] initWithIdentifier:kTestIdentifier
                                              continueURI:kTestContinueURI
                                     requestConfiguration:requestConfiguration];

  __block FIRCreateAuthURIResponse *createAuthURIResponse;
  __block NSError *createAuthURIError;
  __block BOOL callbackInvoked;
  [FIRAuthBackend
      createAuthURI:request
           callback:^(FIRCreateAuthURIResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             createAuthURIResponse = response;
             createAuthURIError = error;
           }];

  XCTAssertEqualObjects(RPCIssuer.requestURL.absoluteString, kTestExpectedRequestURL);
  XCTAssertEqualObjects(RPCIssuer.decodedRequest[@"identifier"], kTestIdentifier);
  XCTAssertEqualObjects(RPCIssuer.decodedRequest[@"continueUri"], kTestContinueURI);

  [RPCIssuer respondWithJSON:@{
    @"kind" : kTestExpectedKind,
    @"allProviders" : @[ kTestProviderID1, kTestProviderID2 ]
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNil(createAuthURIError);
  XCTAssertEqual(createAuthURIResponse.allProviders.count, 2);
  XCTAssertEqualObjects(createAuthURIResponse.allProviders[0], kTestProviderID1);
  XCTAssertEqualObjects(createAuthURIResponse.allProviders[1], kTestProviderID2);
}

@end

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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTwitterAuthProvider.h"

#import "FirebaseAuth/Sources/AuthProvider/FIRAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionRequest.h"

/** @var kTwitterToken
    @brief A testing Twitter token.
 */
static NSString *const kTwitterToken = @"Token";

/** @var kTwitterSecret
    @brief A testing Twitter secret.
 */
static NSString *const kTwitterSecret = @"Secret";

/** @var kAPIKey
    @brief A testing API Key.
 */
static NSString *const kAPIKey = @"APIKey";

/** @class FIRTwitterAuthProviderTests
    @brief Tests for @c FIRTwitterAuthProvider
 */
@interface FIRTwitterAuthProviderTests : XCTestCase
@end
@implementation FIRTwitterAuthProviderTests

/** @fn testCredentialWithToken
    @brief Tests the @c credentialWithToken method to make sure the credential it produces populates
        the appropriate fields in a verify assertion request.
 */
- (void)testCredentialWithToken {
  FIRAuthCredential *credential = [FIRTwitterAuthProvider credentialWithToken:kTwitterToken
                                                                       secret:kTwitterSecret];
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:FIRTwitterAuthProviderID
                                       requestConfiguration:requestConfiguration];
  [credential prepareVerifyAssertionRequest:request];
  XCTAssertEqualObjects(request.providerAccessToken, kTwitterToken);
  XCTAssertEqualObjects(request.providerOAuthTokenSecret, kTwitterSecret);
}

@end

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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRGitHubAuthProvider.h"

#import "FirebaseAuth/Sources/AuthProvider/FIRAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionRequest.h"

/** @var kGitHubToken
    @brief A testing GitHub token.
 */
static NSString *const kGitHubToken = @"Token";

/** @var kAPIKey
    @brief A testing API Key.
 */
static NSString *const kAPIKey = @"APIKey";

/** @class FIRGitHubAuthProviderTests
    @brief Tests for @c FIRGitHubAuthProvider
 */
@interface FIRGitHubAuthProviderTests : XCTestCase
@end
@implementation FIRGitHubAuthProviderTests

/** @fn testCredentialWithToken
    @brief Tests the @c credentialWithToken method to make sure the credential it produces populates
        the appropriate fields in a verify assertion request.
 */
- (void)testCredentialWithToken {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRAuthCredential *credential = [FIRGitHubAuthProvider credentialWithToken:kGitHubToken];
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:FIRGitHubAuthProviderID
                                       requestConfiguration:requestConfiguration];
  [credential prepareVerifyAssertionRequest:request];
  XCTAssertEqualObjects(request.providerAccessToken, kGitHubToken);
}

@end

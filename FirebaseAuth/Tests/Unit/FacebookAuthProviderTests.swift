// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import XCTest

@testable import FirebaseAuth

/** @class FIRFacebookAuthProviderTests
    @brief Tests for @c FIRFacebookAuthProvider
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FacebookAuthProviderTests: XCTestCase {
  /** @fn testCredentialWithToken
      @brief Tests the @c credentialWithToken method to make sure the credential it produces populates
          the appropriate fields in a verify assertion request.
   */
  func testCredentialWithToken() {
    let kFacebookToken = "Token"
    let requestConfiguration = AuthRequestConfiguration(apiKey: "APIKey", appID: "appID")
    let credential = FacebookAuthProvider.credential(withAccessToken: kFacebookToken)
    let request = VerifyAssertionRequest(providerID: FacebookAuthProvider.id,
                                         requestConfiguration: requestConfiguration)
    credential.prepare(request)
    XCTAssertEqual(kFacebookToken, request.providerAccessToken)
  }

  /** @fn testFacebookAuthCredentialCoding
      @brief Tests successful archiving and unarchiving of @c FacebookAuthCredential.
   */
  func testFacebookAuthCredentialCoding() throws {
    let kFacebookToken = "Token"
    let credential = FacebookAuthProvider.credential(withAccessToken: kFacebookToken)
    XCTAssertTrue(FacebookAuthCredential.supportsSecureCoding)
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: credential,
      requiringSecureCoding: true
    )
    let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
      ofClass: FacebookAuthCredential.self, from: data
    ))
    XCTAssertEqual(unarchivedCredential.accessToken, kFacebookToken)
  }
}

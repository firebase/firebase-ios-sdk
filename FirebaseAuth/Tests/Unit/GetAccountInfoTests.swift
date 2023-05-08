// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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

class GetAccountInfoTests: RPCBaseTests {
  /** var kTestAccessToken
      brief testing token.
   */
  let kTestAccessToken = "testAccessToken"

  /** var kIDTokenKey
      brief The key for the "idToken" value in the request. This is actually the STS Access Token,
          despite it's confusing (backwards compatiable) parameter name.
   */
  let kIDTokenKey = "idToken"

  func testGetAccountInfoRequest() throws {
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=APIKey"
    try checkRequest(
      request: makeGetAccountInfoRequest(),
      expected: kExpectedAPIURL,
      key: kIDTokenKey,
      value: kTestAccessToken
    )
  }

  /** fn testGetAccountInfoUnexpectedResponseError
      brief This test simulates an unexpected response returned from server in c GetAccountInfo
          flow.
   */
  func testGetAccountInfoUnexpectedResponseError() throws {
    let kUsersKey = "users"
    try checkBackendError(
      request: makeGetAccountInfoRequest(),
      json: [kUsersKey: ["user1Data", "user2Data"]],
      errorCode: AuthErrorCode.internalError,
      underlyingErrorKey: AuthErrorUtils.userInfoDeserializedResponseKey
    )
  }

  /** @fn testSuccessfulGetAccountInfoResponse
      @brief This test simulates a successful @c GetAccountInfo flow.
   */
  func testSuccessfulGetAccountInfoResponse() throws {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kTestPhotoURL = "testPhotoURL"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kTestDisplayName = "DisplayName"
    let kFederatedIDKey = "federatedId"
    let kTestFederatedID = "testFederatedId"
    let kEmailKey = "email"
    let kTestEmail = "testEmail"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kTestProviderID = "testProviderID"
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"
    let kTestLocalID = "testLocalId"

    var callbackInvoked = false
    var rpcResponse: GetAccountInfoResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: makeGetAccountInfoRequest()) { response, error in
      callbackInvoked = true
      rpcResponse = response as? GetAccountInfoResponse
      rpcError = error as? NSError
    }

    let usersIn = [[
      kProviderUserInfoKey: [[
        kProviderIDkey: kTestProviderID,
        kDisplayNameKey: kTestDisplayName,
        kPhotoUrlKey: kTestPhotoURL,
        kFederatedIDKey: kTestFederatedID,
        kEmailKey: kTestEmail,
      ]],
      kLocalIDKey: kTestLocalID,
      kDisplayNameKey: kTestDisplayName,
      kEmailKey: kTestEmail,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
    ] as [String: Any]]

    _ = try rpcIssuer?.respond(withJSON: ["users": usersIn])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    let users = try XCTUnwrap(rpcResponse?.users)
    XCTAssertGreaterThan(users.count, 0)
    let firstUser = try XCTUnwrap(users.first)
    XCTAssertEqual(firstUser.photoURL?.absoluteString, kTestPhotoURL)
    XCTAssertEqual(firstUser.displayName, kTestDisplayName)
    XCTAssertEqual(firstUser.email, kTestEmail)
    XCTAssertEqual(firstUser.localID, kTestLocalID)
    XCTAssertTrue(firstUser.emailVerified)
    let providerUserInfo = try XCTUnwrap(firstUser.providerUserInfo)
    XCTAssertGreaterThan(providerUserInfo.count, 0)
    let firstProviderUser = try XCTUnwrap(providerUserInfo.first)
    XCTAssertEqual(firstProviderUser.photoURL?.absoluteString, kTestPhotoURL)
    XCTAssertEqual(firstProviderUser.displayName, kTestDisplayName)
    XCTAssertEqual(firstProviderUser.email, kTestEmail)
    XCTAssertEqual(firstProviderUser.providerID, kTestProviderID)
    XCTAssertEqual(firstProviderUser.federatedID, kTestFederatedID)
  }

  private func makeGetAccountInfoRequest() -> GetAccountInfoRequest {
    return GetAccountInfoRequest(accessToken: kTestAccessToken,
                                 requestConfiguration: makeRequestConfiguration())
  }
}

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

class SignInWithGameCenterTests: RPCBaseTests {
  private let kEmailKey = "email"
  private let kTestEmail = "testgmail.com"
  private let kDisplayNameKey = "displayName"
  private let kTestDisplayName = "DisplayName"
  private let kPasswordKey = "password"
  private let kTestPassword = "Password"
  private let kReturnSecureTokenKey = "returnSecureToken"
  private let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signInWithGameCenter?key=APIKey"

  /** @fn testSignInWithGameCenterRequestAnonymous
      @brief Tests the encoding of a sign up new user request when user is signed in anonymously.
   */
  func testRequestResponseEncoding() throws {
    let kIDToken = "IDTOKEN"
    let kRefreshToken = "PUBLICKEYURL"
    let kLocalID = "LOCALID"
    let kPlayerIDKey = "playerId"
    let kPlayerID = "PLAYERID"
    let kTeamPlayerIDKey = "teamPlayerId"
    let kTeamPlayerID = "TEAMPLAYERID"
    let kGamePlayerIDKey = "gamePlayerId"
    let kGamePlayerID = "GAMEPLAYERID"
    let kApproximateExpirationDate = "3600"
    let kDisplayNameKey = "displayName"
    let kDisplayName = "DISPLAYNAME"
    let kPublicKeyURLKey = "publicKeyUrl"
    let kPublicKeyURL = "PUBLICKEYURL"
    let kSignatureKey = "signature"
    let kSignature = "AAAABBBBCCCC"
    let kSaltKey = "salt"
    let kSalt = "AAAA"
    let kTimestampKey = "timestamp"
    let kTimestamp = UInt64(12_345_678)
    let kAccessTokenKey = "idToken"
    let kAccessToken = "ACCESSTOKEN"

    var callbackInvoked = false
    var rpcResponse: SignInWithGameCenterResponse?
    var rpcError: NSError?

    let signature = try XCTUnwrap(Data(base64Encoded: kSignature))
    let salt = try XCTUnwrap(Data(base64URLEncoded: kSalt))
    let request = SignInWithGameCenterRequest(playerID: kPlayerID,
                                              teamPlayerID: kTeamPlayerID,
                                              gamePlayerID: kGamePlayerID,
                                              publicKeyURL: try XCTUnwrap(
                                                URL(string: kPublicKeyURL)
                                              ),
                                              signature: signature,
                                              salt: salt,
                                              timestamp: kTimestamp,
                                              displayName: kDisplayName,
                                              requestConfiguration: makeRequestConfiguration())
    request.accessToken = kAccessToken
    let issuer = try checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kPlayerIDKey,
      value: kPlayerID
    )
    let requestDictionary = try XCTUnwrap(issuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kTeamPlayerIDKey], kTeamPlayerID)
    XCTAssertEqual(requestDictionary[kGamePlayerIDKey], kGamePlayerID)
    XCTAssertEqual(requestDictionary[kPublicKeyURLKey], kPublicKeyURL)
    XCTAssertEqual(requestDictionary[kSignatureKey], kSignature)
    XCTAssertEqual(requestDictionary[kSaltKey], kSalt)
    XCTAssertEqual(requestDictionary[kTimestampKey], kTimestamp)
    XCTAssertEqual(requestDictionary[kAccessTokenKey], kAccessToken)
    XCTAssertEqual(requestDictionary[kDisplayNameKey], kDisplayName)

    AuthBackend.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }

    _ = try rpcIssuer?.respond(withJSON: [
      "idToken": kIDToken,
      "refreshToken": kRefreshToken,
      "localId": kLocalID,
      "playerId": kPlayerID,
      "teamPlayerId": kTeamPlayerID,
      "gamePlayerId": kGamePlayerID,
      "expiresIn": kApproximateExpirationDate,
      "isNewUser": true,
      "displayName": kDisplayName,
    ])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.idToken, kIDToken)
    XCTAssertEqual(rpcResponse?.refreshToken, kRefreshToken)
    XCTAssertEqual(rpcResponse?.localID, kLocalID)
    XCTAssertEqual(rpcResponse?.playerID, kPlayerID)
    XCTAssertEqual(rpcResponse?.teamPlayerID, kTeamPlayerID)
    XCTAssertEqual(rpcResponse?.gamePlayerID, kGamePlayerID)
    XCTAssertEqual(rpcResponse?.displayName, kDisplayName)
    XCTAssertTrue(try XCTUnwrap(rpcResponse?.isNewUser))
  }
}

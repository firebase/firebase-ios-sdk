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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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
  let kIDToken = "IDTOKEN"
  let kPlayerIDKey = "playerId"
  let kPlayerID = "PLAYERID"
  let kTeamPlayerIDKey = "teamPlayerId"
  let kTeamPlayerID = "TEAMPLAYERID"
  let kGamePlayerIDKey = "gamePlayerId"
  let kGamePlayerID = "GAMEPLAYERID"
  let kApproximateExpirationDate = "3600"
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

  /** @fn testSignInWithGameCenterRequestAnonymous
      @brief Tests the encoding of a sign up new user request when user is signed in anonymously.
   */
  func testRequestResponseEncoding() async throws {
    let kRefreshToken = "PUBLICKEYURL"
    let kLocalID = "LOCALID"
    let kDisplayNameKey = "displayName"
    let kDisplayName = "DISPLAYNAME"

    let signature = try XCTUnwrap(Data(base64Encoded: kSignature))
    let salt = try XCTUnwrap(Data(base64Encoded: kSalt))
    let request = try SignInWithGameCenterRequest(playerID: kPlayerID,
                                                  teamPlayerID: kTeamPlayerID,
                                                  gamePlayerID: kGamePlayerID,
                                                  publicKeyURL: XCTUnwrap(
                                                    URL(string: kPublicKeyURL)
                                                  ),
                                                  signature: signature,
                                                  salt: salt,
                                                  timestamp: kTimestamp,
                                                  displayName: kDisplayName,
                                                  requestConfiguration: makeRequestConfiguration())
    request.accessToken = kAccessToken
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kPlayerIDKey,
      value: kPlayerID
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kTeamPlayerIDKey], kTeamPlayerID)
    XCTAssertEqual(requestDictionary[kGamePlayerIDKey], kGamePlayerID)
    XCTAssertEqual(requestDictionary[kPublicKeyURLKey], kPublicKeyURL)
    XCTAssertEqual(requestDictionary[kSignatureKey], kSignature)
    XCTAssertEqual(requestDictionary[kSaltKey], kSalt)
    XCTAssertEqual(requestDictionary[kTimestampKey], kTimestamp)
    XCTAssertEqual(requestDictionary[kAccessTokenKey], kAccessToken)
    XCTAssertEqual(requestDictionary[kDisplayNameKey], kDisplayName)

    rpcIssuer.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [
        "idToken": self.kIDToken,
        "refreshToken": kRefreshToken,
        "localId": kLocalID,
        "playerId": self.kPlayerID,
        "teamPlayerId": self.kTeamPlayerID,
        "gamePlayerId": self.kGamePlayerID,
        "expiresIn": self.kApproximateExpirationDate,
        "isNewUser": true,
        "displayName": kDisplayName,
      ])
    }
    let rpcResponse = try await AuthBackend.call(with: request)
    XCTAssertNotNil(rpcResponse)

    XCTAssertEqual(rpcResponse.idToken, kIDToken)
    XCTAssertEqual(rpcResponse.refreshToken, kRefreshToken)
    XCTAssertEqual(rpcResponse.localID, kLocalID)
    XCTAssertEqual(rpcResponse.playerID, kPlayerID)
    XCTAssertEqual(rpcResponse.teamPlayerID, kTeamPlayerID)
    XCTAssertEqual(rpcResponse.gamePlayerID, kGamePlayerID)
    XCTAssertEqual(rpcResponse.displayName, kDisplayName)
    XCTAssertTrue(rpcResponse.isNewUser)
  }

  #if !os(watchOS)
    /** @fn testGameCenterAuthCredentialCoding
        @brief Tests successful archiving and unarchiving of @c GameCenterAuthCredential.
     */
    func testGameCenterAuthCredentialCoding() throws {
      let credential = try makeGameCenterCredential()
      XCTAssertTrue(GameCenterAuthCredential.supportsSecureCoding)
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: credential,
        requiringSecureCoding: true
      )
      let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
        ofClasses: [NSURL.self, GameCenterAuthCredential.self], from: data
      ) as? GameCenterAuthCredential)
      XCTAssertEqual(unarchivedCredential.playerID, kPlayerID)
      XCTAssertEqual(unarchivedCredential.teamPlayerID, kTeamPlayerID)
      XCTAssertEqual(unarchivedCredential.gamePlayerID, kGamePlayerID)
      XCTAssertEqual(unarchivedCredential.publicKeyURL, URL(string: kPublicKeyURL))
      XCTAssertEqual(try String(data: XCTUnwrap(unarchivedCredential.signature),
                                encoding: .utf8), kSignature)
      XCTAssertEqual(try String(data: XCTUnwrap(unarchivedCredential.salt), encoding: .utf8), kSalt)
      XCTAssertEqual(unarchivedCredential.timestamp, kTimestamp)
      XCTAssertEqual(unarchivedCredential.displayName, kDisplayName)
    }

    private func makeGameCenterCredential() throws -> GameCenterAuthCredential {
      let signature = try XCTUnwrap(kSignature.data(using: .utf8))
      let salt = try XCTUnwrap(kSalt.data(using: .utf8))
      return try GameCenterAuthCredential(withPlayerID: kPlayerID,
                                          teamPlayerID: kTeamPlayerID,
                                          gamePlayerID: kGamePlayerID,
                                          publicKeyURL: XCTUnwrap(
                                            URL(string: kPublicKeyURL)
                                          ),
                                          signature: signature,
                                          salt: salt,
                                          timestamp: kTimestamp,
                                          displayName: kDisplayName)
    }
  #endif
}

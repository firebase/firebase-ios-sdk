// Copyright 2021 Google LLC
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

import Combine
import FirebaseAuth
import Foundation
import XCTest

class SignInWithGameCenterTests: XCTestCase {
  override class func setUp() {
    FirebaseApp.configureForTests()
  }

  override class func tearDown() {
    FirebaseApp.app()?.delete { success in
      if success {
        print("Shut down app successfully.")
      } else {
        print("💥 There was a problem when shutting down the app..")
      }
    }
  }

  fileprivate static let expectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signInWithGameCenter?key=APIKEY"
  fileprivate static let testAPI = "APIKEY"
  fileprivate static let idTokenKey = "idToken"
  fileprivate static let idToken = "IDTOKEN"
  fileprivate static let refreshTokenKey = "refreshToken"
  fileprivate static let refreshToken = "PUBLICKEYURL"
  fileprivate static let localIDKey = "localId"
  fileprivate static let localID = "LOCALID"
  fileprivate static let playerIDKey = "playerId"
  fileprivate static let playerID = "PLAYERID"
  fileprivate static let teamPlayerID = "TEAMPLAYERID"
  fileprivate static let gamePlayerID = "GAMEPLAYERID"
  fileprivate static let approximateExpirationDateKey = "expiresIn"
  fileprivate static let approximateExpirationDate = "3600"
  fileprivate static let isNewUserKey = "isNewUser"
  fileprivate static let isNewUser = true
  fileprivate static let displayNameKey = "displayName"
  fileprivate static let displayName = "DISPLAYNAME"
  fileprivate static let publicKeyURLKey = "publicKeyUrl"
  fileprivate static let publicKeyURL = "PUBLICKEYURL"
  fileprivate static let signatureKey = "signature"
  fileprivate static let signature = "AAAABBBBCCCC"
  fileprivate static let saltKey = "salt"
  fileprivate static let salt = "AAAA"
  fileprivate static let timestampKey = "timestamp"
  fileprivate static let timestamp: UInt64 = 12_345_678
  fileprivate static let accessTokenKey = "idToken"
  fileprivate static let accessToken = "ACCESSTOKEN"

  class MockBackendRPCIssuer: NSObject, FIRAuthBackendRPCIssuer {
    var requestURL: URL?
    var requestData: Data?
    var decodedRequest: [String: Any]?
    var contentType: String?
    var handler: FIRAuthBackendRPCIssuerCompletionHandler?

    func asyncCallToURL(with requestConfiguration: FIRAuthRequestConfiguration, url URL: URL,
                        body: Data?, contentType: String,
                        completionHandler handler: @escaping FIRAuthBackendRPCIssuerCompletionHandler) {
      requestURL = URL
      if let body {
        requestData = body
        let json = try! JSONSerialization
          .jsonObject(with: body, options: []) as! [String: Any]
        decodedRequest = json
      }
      self.contentType = contentType
      self.handler = handler
    }

    @discardableResult
    func respond(withJSON JSON: [String: Any]) throws -> Data {
      let data = try JSONSerialization.data(
        withJSONObject: JSON,
        options: JSONSerialization.WritingOptions.prettyPrinted
      )
      XCTAssertNotNil(handler)
      handler?(data, nil)
      return data
    }
  }

  override func setUp() {
    do {
      try Auth.auth().signOut()
    } catch {}
  }

  func testRequestResponseEncoding() {
    // given
    let RPCIssuer = MockBackendRPCIssuer()
    FIRAuthBackend.setDefaultBackendImplementationWith(RPCIssuer)

    let signature = Data(base64Encoded: Self.signature)!
    let salt = Data(base64Encoded: Self.salt)!
    let requestConfiguration = FIRAuthRequestConfiguration(apiKey: Self.testAPI, appID: "appID")!

    let request = FIRSignInWithGameCenterRequest(
      playerID: Self.playerID,
      teamPlayerID: Self.teamPlayerID,
      gamePlayerID: Self.gamePlayerID,
      publicKeyURL: URL(string: Self.publicKeyURL)!,
      signature: signature,
      salt: salt,
      timestamp: Self.timestamp,
      displayName: Self.displayName,
      requestConfiguration: requestConfiguration
    )!

    request.accessToken = Self.accessToken

    var cancellables = Set<AnyCancellable>()
    let signInWithGameCenterExpectation = expectation(description: "Sign in Game Center")

    // when
    FIRAuthBackend.signIn(withGameCenter: request)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { response in
        XCTAssertEqual(RPCIssuer.requestURL?.absoluteString, Self.expectedAPIURL)
        XCTAssertNotNil(RPCIssuer.decodedRequest)
        XCTAssertEqual(
          RPCIssuer.decodedRequest?[Self.playerIDKey] as? String,
          Self.playerID
        )
        XCTAssertEqual(
          RPCIssuer.decodedRequest?[Self.publicKeyURLKey] as? String,
          Self.publicKeyURL
        )
        XCTAssertEqual(
          RPCIssuer.decodedRequest?[Self.signatureKey] as? String,
          Self.signature
        )
        XCTAssertEqual(RPCIssuer.decodedRequest?[Self.saltKey] as? String, Self.salt)
        XCTAssertEqual(
          RPCIssuer.decodedRequest?[Self.timestampKey] as? UInt64,
          Self.timestamp
        )
        XCTAssertEqual(
          RPCIssuer.decodedRequest?[Self.accessTokenKey] as? String,
          Self.accessToken
        )
        XCTAssertEqual(
          RPCIssuer.decodedRequest?[Self.displayNameKey] as? String,
          Self.displayName
        )

        XCTAssertNotNil(response)
        XCTAssertEqual(response.idToken, Self.idToken)
        XCTAssertEqual(response.refreshToken, Self.refreshToken)
        XCTAssertEqual(response.localID, Self.localID)
        XCTAssertEqual(response.playerID, Self.playerID)
        XCTAssertEqual(response.isNewUser, Self.isNewUser)
        XCTAssertEqual(response.displayName, Self.displayName)

        signInWithGameCenterExpectation.fulfill()
      }
      .store(in: &cancellables)

    let jsonDictionary: [String: Any] = [
      "idToken": Self.idToken,
      "refreshToken": Self.refreshToken,
      "localId": Self.localID,
      "playerId": Self.playerID,
      "expiresIn": Self.approximateExpirationDate,
      "isNewUser": Self.isNewUser,
      "displayName": Self.displayName,
    ]

    try! RPCIssuer.respond(withJSON: jsonDictionary)

    // then
    wait(for: [signInWithGameCenterExpectation], timeout: expectationTimeout)
  }
}

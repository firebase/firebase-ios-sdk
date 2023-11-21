// Copyright 2020 Google LLC
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

class SignInWithCustomTokenTests: XCTestCase {
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

  override func setUp() {
    do {
      try Auth.auth().signOut()
    } catch {}
  }

  static let apiKey = Credentials.apiKey
  static let accessTokenTimeToLive: TimeInterval = 60 * 60
  static let refreshToken = "REFRESH_TOKEN"
  static let accessToken = "ACCESS_TOKEN"

  static let email = "johnnyappleseed@apple.com"
  static let password = "secret"
  static let localID = "LOCAL_ID"
  static let displayName = "Johnny Appleseed"
  static let passwordHash = "UkVEQUNURUQ="

  static let oAuthSessionID = "sessionID"
  static let oAuthRequestURI = "requestURI"
  static let googleID = "GOOGLE_ID"
  static let googleDisplayName = "Google Doe"
  static let googleEmail = "user@gmail.com"

  static let customToken = "CUSTOM_TOKEN"

  class MockVerifyCustomTokenResponse: FIRVerifyCustomTokenResponse {
    override var idToken: String { return SignInWithCustomTokenTests.accessToken }
    override var refreshToken: String { return SignInWithCustomTokenTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: SignInWithCustomTokenTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String? { return SignInWithCustomTokenTests.localID }
    override var displayName: String { return SignInWithCustomTokenTests.displayName }
    override var email: String? { return SignInWithCustomTokenTests.email }
    override var passwordHash: String? { return SignInWithCustomTokenTests.passwordHash }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func verifyCustomToken(_ request: FIRVerifyCustomTokenRequest,
                                    callback: @escaping FIRVerifyCustomTokenResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCustomTokenTests.apiKey)
      XCTAssertEqual(request.token, SignInWithCustomTokenTests.customToken)
      XCTAssertTrue(request.returnSecureToken)

      callback(MockVerifyCustomTokenResponse(), nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCustomTokenTests.apiKey)
      XCTAssertEqual(request.accessToken, SignInWithCustomTokenTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }
  }

  func testSignInWithCustomToken() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    // when
    Auth.auth()
      .signIn(withCustomToken: SignInWithCustomTokenTests.customToken)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        let user = authDataResult.user
        XCTAssertNotNil(user)
        XCTAssertEqual(user.uid, SignInWithCustomTokenTests.localID)
        XCTAssertEqual(user.displayName, SignInWithCustomTokenTests.displayName)
        XCTAssertEqual(user.email, SignInWithCustomTokenTests.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerData.count, 0)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }
}

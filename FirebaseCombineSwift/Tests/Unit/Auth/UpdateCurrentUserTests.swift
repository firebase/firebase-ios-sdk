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

class UpdateCurrentUserTests: XCTestCase {
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

  class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
    override var idToken: String { return UpdateCurrentUserTests.accessToken }
    override var refreshToken: String { return UpdateCurrentUserTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: UpdateCurrentUserTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String? { return UpdateCurrentUserTests.localID }
    override var displayName: String { return UpdateCurrentUserTests.displayName }
    override var email: String? { return UpdateCurrentUserTests.email }
    override var passwordHash: String? { return UpdateCurrentUserTests.passwordHash }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func verifyPassword(_ request: FIRVerifyPasswordRequest,
                                 callback: @escaping FIRVerifyPasswordResponseCallback) {
      callback(MockVerifyPasswordResponse(), nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCustomTokenTests.apiKey)
      XCTAssertEqual(request.accessToken, SignInWithCustomTokenTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }
  }

  func waitForSignIn(with accessToken: String, apiKey: String) {
    let userSignedInExpectation = expectation(description: "User signed in")
    let cancellable = Auth.auth()
      .signIn(withEmail: UpdateCurrentUserTests.email, password: UpdateCurrentUserTests.password)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        userSignedInExpectation.fulfill()
      }

    wait(for: [userSignedInExpectation], timeout: expectationTimeout)
    XCTAssertNotNil(Auth.auth().currentUser)
    cancellable.cancel()
  }

  func testUpdateCurrentUser() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userUpdated = expectation(description: "Current user updated")

    // when
    waitForSignIn(with: UpdateCurrentUserTests.accessToken, apiKey: UpdateCurrentUserTests.apiKey)
    guard let user1 = Auth.auth().currentUser else {
      XCTFail("Current user unexpectedly was nil")
      return
    }

    let accessToken2 = "fakeAccessToken2"
    waitForSignIn(with: accessToken2, apiKey: UpdateCurrentUserTests.apiKey)
    guard let user2 = Auth.auth().currentUser else {
      XCTFail("Current user unexpectedly was nil")
      return
    }

    XCTAssertEqual(Auth.auth().currentUser, user2)

    Auth.auth()
      .updateCurrentUser(user1)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: {
        XCTAssertEqual(Auth.auth().currentUser, user1)
        XCTAssertNotEqual(Auth.auth().currentUser, user2)
        userUpdated.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userUpdated], timeout: expectationTimeout)
  }
}

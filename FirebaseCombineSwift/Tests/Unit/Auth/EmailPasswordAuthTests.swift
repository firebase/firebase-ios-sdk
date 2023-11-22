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

class EmailPasswordAuthTests: XCTestCase {
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

  class MockSignUpNewUserResponse: FIRSignUpNewUserResponse {
    override var idToken: String { return EmailPasswordAuthTests.accessToken }
    override var refreshToken: String { return EmailPasswordAuthTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: EmailPasswordAuthTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String { return EmailPasswordAuthTests.localID }
    override var email: String { return EmailPasswordAuthTests.email }
    override var displayName: String { return EmailPasswordAuthTests.displayName }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
    override var localID: String { return EmailPasswordAuthTests.localID }
    override var email: String { return EmailPasswordAuthTests.email }
    override var displayName: String { return EmailPasswordAuthTests.displayName }
    override var idToken: String { return EmailPasswordAuthTests.accessToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: EmailPasswordAuthTests.accessTokenTimeToLive)
    }

    override var refreshToken: String { return EmailPasswordAuthTests.refreshToken }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func signUpNewUser(_ request: FIRSignUpNewUserRequest,
                                callback: @escaping FIRSignupNewUserCallback) {
      XCTAssertEqual(request.apiKey, EmailPasswordAuthTests.apiKey)
      XCTAssertEqual(request.email, EmailPasswordAuthTests.email)
      XCTAssertEqual(request.password, EmailPasswordAuthTests.password)
      XCTAssertTrue(request.returnSecureToken)
      let response = MockSignUpNewUserResponse()
      callback(response, nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, EmailPasswordAuthTests.apiKey)
      XCTAssertEqual(request.accessToken, EmailPasswordAuthTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }

    override func verifyPassword(_ request: FIRVerifyPasswordRequest,
                                 callback: @escaping FIRVerifyPasswordResponseCallback) {
      let response = MockVerifyPasswordResponse()
      callback(response, nil)
    }
  }

  func testCreateUserWithEmailAndPassword() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()

    let userCreatedExpectation = expectation(description: "User created")

    // when
    Auth.auth()
      .createUser(
        withEmail: EmailPasswordAuthTests.email,
        password: EmailPasswordAuthTests.password
      )
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
        XCTAssertEqual(user.uid, EmailPasswordAuthTests.localID)
        XCTAssertEqual(user.displayName, EmailPasswordAuthTests.displayName)
        XCTAssertEqual(user.email, EmailPasswordAuthTests.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerData.count, 0)

        userCreatedExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userCreatedExpectation], timeout: expectationTimeout)
  }

  func testSignInUserWithEmailAndPassword() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    // when
    Auth.auth()
      .signIn(withEmail: EmailPasswordAuthTests.email, password: EmailPasswordAuthTests.password)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, EmailPasswordAuthTests.email)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }
}

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

class AnonymousAuthTests: XCTestCase {
  static let apiKey = Credentials.apiKey
  static let accessTokenTimeToLive: TimeInterval = 60 * 60
  static let refreshToken = "REFRESH_TOKEN"
  static let accessToken = "ACCESS_TOKEN"
  static let localID = "LOCAL_ID"

  class MockSignUpNewUserResponse: FIRSignUpNewUserResponse {
    override var idToken: String { return AnonymousAuthTests.accessToken }
    override var refreshToken: String { return AnonymousAuthTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: AnonymousAuthTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String { return AnonymousAuthTests.localID }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func signUpNewUser(_ request: FIRSignUpNewUserRequest,
                                callback: @escaping FIRSignupNewUserCallback) {
      XCTAssertEqual(request.apiKey, AnonymousAuthTests.apiKey)
      XCTAssertNil(request.email)
      XCTAssertNil(request.password)
      XCTAssertTrue(request.returnSecureToken)
      let response = MockSignUpNewUserResponse()
      callback(response, nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, AnonymousAuthTests.apiKey)
      XCTAssertEqual(request.accessToken, AnonymousAuthTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }
  }

  // MARK: - Test case setup

  override class func setUp() {
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
  }

  // MARK: - Test method setup

  var app: FirebaseApp?
  var auth: Auth?

  override func setUp() {
    self.app = FirebaseApp.appForAuthUnitTestsWithName(name: "app1")
    guard let app = app else { fatalError() }
    auth = Auth.auth(app: app)
  }

  func testSignInAnonymouslySuccessfully() {
    // given
    var cancellables = Set<AnyCancellable>()
    let userSignedInExpectation = expectation(description: "Signed in anonymously")

    // when
    auth?.signInAnonymously()
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.uid, AnonymousAuthTests.localID)
        XCTAssertNil(authDataResult.user.displayName)
        XCTAssertTrue(authDataResult.user.isAnonymous)
        XCTAssertEqual(authDataResult.user.providerData.count, 0)

        XCTAssertNotNil(authDataResult.additionalUserInfo)
        XCTAssertTrue((authDataResult.additionalUserInfo?.isNewUser) != nil)
        XCTAssertNil(authDataResult.additionalUserInfo?.username)
        XCTAssertNil(authDataResult.additionalUserInfo?.profile)

        userSignedInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignedInExpectation], timeout: expectationTimeout)
  }
}

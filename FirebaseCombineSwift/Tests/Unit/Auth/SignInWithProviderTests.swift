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

class SignInWithProviderTests: XCTestCase {
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

  class MockAuthProvider: OAuthProvider {
    static func provider(with providerID: String) -> OAuthProvider {
      super.init(providerID: providerID)
    }

    override func getCredentialWith(_ UIDelegate: AuthUIDelegate?,
                                    completion: ((AuthCredential?, Error?) -> Void)? = nil) {
      guard let completion = completion else { return }
      let credential = OAuthCredential(providerID: GoogleAuthProvider.id,
                                       sessionID: SignInWithProviderTests.oAuthSessionID,
                                       oAuthResponseURLString: SignInWithProviderTests
                                         .oAuthRequestURI)
      completion(credential, nil)
    }
  }

  class MockVerifyAssertionResponse: FIRVerifyAssertionResponse {
    override var federatedID: String? { return SignInWithProviderTests.googleID }
    override var providerID: String? { return GoogleAuthProvider.id }
    override var localID: String? { return SignInWithProviderTests.localID }
    override var displayName: String? { return SignInWithProviderTests.displayName }

    override var idToken: String { return EmailPasswordAuthTests.accessToken }
    override var refreshToken: String { return EmailPasswordAuthTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: EmailPasswordAuthTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseProviderUserInfo: FIRGetAccountInfoResponseProviderUserInfo {
    override var providerID: String? { return GoogleAuthProvider.id }
    override var displayName: String? { return SignInWithProviderTests.googleDisplayName }
    override var federatedID: String? { return SignInWithProviderTests.googleID }
    override var email: String? { return SignInWithProviderTests.googleEmail }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String? { return SignInWithProviderTests.localID }
    override var displayName: String { return SignInWithProviderTests.displayName }
    override var providerUserInfo: [FIRGetAccountInfoResponseProviderUserInfo]? {
      return [MockGetAccountInfoResponseProviderUserInfo(dictionary: [:])]
    }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func verifyAssertion(_ request: FIRVerifyAssertionRequest,
                                  callback: @escaping FIRVerifyAssertionResponseCallback) {
      XCTAssertEqual(request.apiKey, EmailPasswordAuthTests.apiKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertTrue(request.returnSecureToken)

      let response = MockVerifyAssertionResponse()
      callback(response, nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithProviderTests.apiKey)
      XCTAssertEqual(request.accessToken, SignInWithProviderTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }
  }

  func testSignInUserWithEmailAndPassword() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    let authProvider = MockAuthProvider.provider(with: "mockProvider")

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    // when
    Auth.auth()
      .signIn(with: authProvider, uiDelegate: nil)
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
        XCTAssertEqual(user.uid, SignInWithProviderTests.localID)
        XCTAssertEqual(user.displayName, SignInWithProviderTests.displayName)
        XCTAssertEqual(user.providerData.count, 1)
        let userInfo = user.providerData[0]
        XCTAssertEqual(userInfo.providerID, GoogleAuthProvider.id)
        XCTAssertEqual(userInfo.uid, SignInWithProviderTests.googleID)
        XCTAssertEqual(userInfo.displayName, SignInWithProviderTests.googleDisplayName)
        XCTAssertEqual(userInfo.email, SignInWithProviderTests.googleEmail)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }
}

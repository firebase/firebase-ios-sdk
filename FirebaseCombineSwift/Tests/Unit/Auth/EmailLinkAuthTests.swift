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

class EmailLinkAuthTests: XCTestCase {
  static let apiKey = Credentials.apiKey
  static let accessTokenTimeToLive: TimeInterval = 60 * 60
  static let refreshToken = "REFRESH_TOKEN"
  static let accessToken = "ACCESS_TOKEN"

  static let email = "johnnyappleseed@apple.com"
  static let password = "secret"
  static let localID = "LOCAL_ID"
  static let displayName = "Johnny Appleseed"
  static let passwordHash = "UkVEQUNURUQ="

  static let fakeEmailSignInlink =
    "https://test.app.goo.gl/?link=https://test.firebaseapp.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://test.apps.com"
  static let fakeOOBCode = "testoobcode"
  static let continueURL = "continueURL"

  class MockEmailLinkSignInResponse: FIREmailLinkSignInResponse {
    override var idToken: String { return EmailLinkAuthTests.accessToken }
    override var refreshToken: String { return EmailLinkAuthTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: EmailLinkAuthTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String { return EmailLinkAuthTests.localID }
    override var email: String { return EmailLinkAuthTests.email }
    override var displayName: String { return EmailLinkAuthTests.displayName }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockGetOOBConfirmationCodeResponse: FIRGetOOBConfirmationCodeResponse {
    override var oobCode: String { return EmailLinkAuthTests.fakeOOBCode }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, EmailLinkAuthTests.apiKey)
      XCTAssertEqual(request.accessToken, EmailLinkAuthTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }

    override func emailLinkSignin(_ request: FIREmailLinkSignInRequest,
                                  callback: @escaping FIREmailLinkSigninResponseCallback) {
      XCTAssertEqual(request.apiKey, EmailLinkAuthTests.apiKey)
      XCTAssertEqual(request.email, EmailLinkAuthTests.email)
      XCTAssertEqual(request.oobCode, EmailLinkAuthTests.fakeOOBCode)
      callback(MockEmailLinkSignInResponse(), nil)
    }

    override func getOOBConfirmationCode(_ request: FIRGetOOBConfirmationCodeRequest,
                                         callback: @escaping FIRGetOOBConfirmationCodeResponseCallback) {
      XCTAssertEqual(request.apiKey, EmailLinkAuthTests.apiKey)
      XCTAssertEqual(request.email, EmailLinkAuthTests.email)
      XCTAssertEqual(request.continueURL, EmailLinkAuthTests.continueURL)
      XCTAssertTrue(request.handleCodeInApp)
      callback(MockGetOOBConfirmationCodeResponse(), nil)
    }
  }

  func app() -> FirebaseApp {
    FirebaseApp.appForAuthUnitTestsWithName(name: "app1")
  }

  func testSignInUserWithEmailAndLink() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    let auth = Auth.auth(app: app())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    // when
    auth
      .signIn(withEmail: EmailLinkAuthTests.email, link: EmailLinkAuthTests.fakeEmailSignInlink)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.refreshToken, EmailLinkAuthTests.refreshToken)
        XCTAssertFalse(authDataResult.user.isAnonymous)
        XCTAssertEqual(authDataResult.user.email, EmailLinkAuthTests.email)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSendSignInLinkToEmail() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    let auth = Auth.auth(app: app())

    var cancellables = Set<AnyCancellable>()
    let sendSignInLinkExpectation = expectation(description: "Sign in link sent")
    let actionSettings = ActionCodeSettings()
    actionSettings.url = URL(string: EmailLinkAuthTests.continueURL)
    actionSettings.handleCodeInApp = true

    // when
    auth
      .sendSignInLink(toEmail: EmailLinkAuthTests.email, actionCodeSettings: actionSettings)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: {
        sendSignInLinkExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [sendSignInLinkExpectation], timeout: expectationTimeout)
  }
}

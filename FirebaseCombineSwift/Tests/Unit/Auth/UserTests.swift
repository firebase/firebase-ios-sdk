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

import Foundation
import Combine
import XCTest
import FirebaseAuth

class UserTests: XCTestCase {
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

  fileprivate struct ProviderCredentials {
    var providerID: String
    var federatedID: String
    var displayName: String
    var providerIDToken: String?
    var providerAccessToken: String
    var email: String
  }

  fileprivate static let passwordHash = "UkVEQUNURUQ="
  fileprivate static let accessTokenTimeToLive: TimeInterval = 60 * 60
  fileprivate static let refreshToken = "REFRESH_TOKEN"
  fileprivate static let accessToken = "ACCESS_TOKEN"
  fileprivate static let email = "user@company.com"
  fileprivate static let password = "!@#$%^"
  fileprivate static let userName = "User Doe"
  fileprivate static let localID = "localId"
  fileprivate static let googleEmail = "user@gmail.com"
  fileprivate static let googleProfile: [String: String] = {
    [
      "iss": "https://accounts.google.com\\",
      "email": googleEmail,
      "given_name": "User",
      "family_name": "Doe",
    ]
  }()

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    fileprivate var providerCredentials: ProviderCredentials!

    override var users: [FIRGetAccountInfoResponseUser] {
      let response = MockGetAccountInfoResponseUser(dictionary: [:])
      response.providerCredentials = providerCredentials
      return [response]
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    fileprivate var providerCredentials: ProviderCredentials!

    override var localID: String { UserTests.localID }
    override var email: String { providerCredentials.email }
    override var displayName: String { providerCredentials.displayName }
    override var passwordHash: String? { UserTests.passwordHash }
    override var providerUserInfo: [FIRGetAccountInfoResponseProviderUserInfo]? {
      let response = MockGetAccountInfoResponseProviderUserInfo(dictionary: [:])
      response.providerCredentials = providerCredentials
      return [response]
    }
  }

  class MockVerifyAssertionResponse: FIRVerifyAssertionResponse {
    fileprivate var providerCredentials: ProviderCredentials!

    override var localID: String? { UserTests.localID }
    override var federatedID: String? { providerCredentials.federatedID }
    override var providerID: String? { providerCredentials.providerID }
    override var displayName: String? { providerCredentials.displayName }
    override var profile: [String: NSObject]? { googleProfile as [String: NSString] }
    override var username: String? { userName }
    override var idToken: String? { accessToken }
    override var refreshToken: String? { UserTests.refreshToken }
    override var approximateExpirationDate: Date? {
      Date(timeIntervalSinceNow: accessTokenTimeToLive)
    }
  }

  class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
    override var refreshToken: String { UserTests.refreshToken }
    override var email: String { UserTests.email }
    override var idToken: String { UserTests.accessToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: UserTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseProviderUserInfo: FIRGetAccountInfoResponseProviderUserInfo {
    fileprivate var providerCredentials: ProviderCredentials!

    override var providerID: String? { providerCredentials.providerID }
    override var displayName: String? { providerCredentials.displayName }
    override var federatedID: String? { providerCredentials.federatedID }
    override var email: String? { googleEmail }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    fileprivate var providerCredentials: ProviderCredentials!

    var verifyAssertionCallback: Result<MockVerifyAssertionResponse, Error> =
      .success(MockVerifyAssertionResponse())
    override func verifyAssertion(_ request: FIRVerifyAssertionRequest,
                                  callback: @escaping FIRVerifyAssertionResponseCallback) {
      XCTAssertEqual(request.apiKey, Credentials.apiKey)
      XCTAssertEqual(request.providerID, providerCredentials.providerID)
      XCTAssertEqual(request.providerIDToken, providerCredentials.providerIDToken)
      XCTAssertEqual(request.providerAccessToken, providerCredentials.providerAccessToken)
      XCTAssertTrue(request.returnSecureToken)

      switch verifyAssertionCallback {
      case let .success(response):
        response.providerCredentials = providerCredentials
        callback(response, nil)
      case let .failure(error):
        callback(nil, error)
      }
    }

    override func verifyPassword(_ request: FIRVerifyPasswordRequest,
                                 callback: @escaping FIRVerifyPasswordResponseCallback) {
      let response = MockVerifyPasswordResponse()
      callback(response, nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, Credentials.apiKey)
      XCTAssertEqual(request.accessToken, accessToken)

      let response = MockGetAccountInfoResponse()
      response.providerCredentials = providerCredentials
      callback(response, nil)
    }
  }

  func testlinkAndRetrieveDataSuccess() {
    let facebookCredentials = ProviderCredentials(
      providerID: FacebookAuthProviderID,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      providerIDToken: nil,
      providerAccessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.providerAccessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] (authResult) -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProviderID)

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProviderID,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          providerIDToken: "GOOGLE_ID_TOKEN",
          providerAccessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail
        )

        authBackend?.providerCredentials = googleCredentials

        let linkGoogleCredential = GoogleAuthProvider.credential(
          withIDToken: googleCredentials.providerIDToken!,
          accessToken: googleCredentials.providerAccessToken
        )
        return authResult.user
          .link(with: linkGoogleCredential)
      }
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { linkAuthResult in
        let user = linkAuthResult.user
        // Verify that the current user and reauthenticated user are same pointers.
        XCTAssertEqual(Auth.auth().currentUser, user)
        XCTAssertEqual(linkAuthResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(linkAuthResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(linkAuthResult.additionalUserInfo?.providerID,
                       GoogleAuthProviderID)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testLinkAndRetrieveDataError() {
    let facebookCredentials = ProviderCredentials(
      providerID: FacebookAuthProviderID,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      providerIDToken: nil,
      providerAccessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.providerAccessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] (authResult) -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProviderID)
        XCTAssertEqual(Auth.auth().currentUser, authResult.user)

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProviderID,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          providerIDToken: "GOOGLE_ID_TOKEN",
          providerAccessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail
        )

        authBackend?.providerCredentials = googleCredentials
        authBackend?
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .accountExistsWithDifferentCredentialError(
              withEmail: UserTests.userName,
              updatedCredential: nil
            ))

        let linkGoogleCredential = GoogleAuthProvider.credential(
          withIDToken: googleCredentials.providerIDToken!,
          accessToken: googleCredentials.providerAccessToken
        )
        return authResult.user
          .link(with: linkGoogleCredential)
      }
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(
            error.code,
            AuthErrorCode.accountExistsWithDifferentCredential.rawValue
          )

          userSignInExpectation.fulfill()
        }
      } receiveValue: { linkAuthResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testLinkAndRetrieveDataProviderAlreadyLinked() {
    let facebookCredentials = ProviderCredentials(
      providerID: FacebookAuthProviderID,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      providerIDToken: nil,
      providerAccessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.providerAccessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] (authResult) -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProviderID)
        XCTAssertEqual(Auth.auth().currentUser, authResult.user)

        authBackend?.providerCredentials = facebookCredentials
        authBackend?
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .accountExistsWithDifferentCredentialError(
              withEmail: UserTests.userName,
              updatedCredential: nil
            ))

        let linkFacebookCredential = FacebookAuthProvider
          .credential(withAccessToken: facebookCredentials.providerAccessToken)
        return authResult.user
          .link(with: linkFacebookCredential)
      }
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.providerAlreadyLinked.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { linkAuthResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testLinkAndRetrieveDataErrorAutoSignOut() {
    let facebookCredentials = ProviderCredentials(
      providerID: FacebookAuthProviderID,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      providerIDToken: nil,
      providerAccessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.providerAccessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] (authResult) -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProviderID)
        XCTAssertEqual(Auth.auth().currentUser, authResult.user)

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProviderID,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          providerIDToken: "GOOGLE_ID_TOKEN",
          providerAccessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail
        )

        authBackend?.providerCredentials = googleCredentials
        authBackend?
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .userDisabledError(withMessage: nil))

        let linkGoogleCredential = GoogleAuthProvider.credential(
          withIDToken: googleCredentials.providerIDToken!,
          accessToken: googleCredentials.providerAccessToken
        )
        return authResult.user
          .link(with: linkGoogleCredential)
      }
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.userDisabled.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { linkAuthResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }
}

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
    var idToken: String?
    var accessToken: String
    var email: String
    var localID: String
    var phoneNumber: String? = nil
    var userInfo: [String: String]? = [:]
  }

  fileprivate static let continueURL = "continueURL"
  fileprivate static let fakeOOBCode = "testoobcode"
  fileprivate static let phoneNumber = "12345658"
  fileprivate static let verificationID = "55432"
  fileprivate static let verificationCode = "12345678"
  fileprivate static let accessTokenTimeToLive: TimeInterval = 60 * 60
  fileprivate static let approximateExpirationDate: TimeInterval = 60 * 60
  fileprivate static let refreshToken = "REFRESH_TOKEN"
  fileprivate static let accessToken = "ACCESS_TOKEN"
  fileprivate static let newAccessToken = "NewAccessToken"
  fileprivate static let email = "user@company.com"
  fileprivate static let password = "!@#$%^"
  fileprivate static let passwordHash = "UkVEQUNURUQ="
  fileprivate static let userName = "User Doe"
  fileprivate static let localID = "localId"
  fileprivate static let googleEmail = "user@gmail.com"
  fileprivate static let googleProfile: [String: String] = [
    "iss": "https://accounts.google.com\\",
    "email": googleEmail,
    "given_name": "User",
    "family_name": "Doe",
  ]

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    fileprivate var providerCredentials: ProviderCredentials!

    override var users: [FIRGetAccountInfoResponseUser] {
      let response = MockGetAccountInfoResponseUser(dictionary: [:])
      response.providerCredentials = providerCredentials
      return [response]
    }
  }

  class MockSetAccountInfoResponse: FIRSetAccountInfoResponse {}

  class MockSecureAccessResponse: FIRSecureTokenResponse {
    override var accessToken: String { return "ACCESS_TOKEN" }
  }

  class MockVerifyPhoneNumberResponse: FIRVerifyPhoneNumberResponse {
    fileprivate var providerCredentials: ProviderCredentials!

    override var phoneNumber: String? { providerCredentials.phoneNumber }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    fileprivate var providerCredentials: ProviderCredentials!

    override var localID: String { providerCredentials.localID }
    override var email: String { providerCredentials.email }
    override var displayName: String { providerCredentials.displayName }
    override var passwordHash: String? { UserTests.passwordHash }
    override var phoneNumber: String? { providerCredentials.phoneNumber }
    override var providerUserInfo: [FIRGetAccountInfoResponseProviderUserInfo]? {
      guard let userInfo = providerCredentials.userInfo else {
        return nil
      }
      let response = MockGetAccountInfoResponseProviderUserInfo(dictionary: userInfo)
      response.providerCredentials = providerCredentials
      return [response]
    }
  }

  class MockVerifyAssertionResponse: FIRVerifyAssertionResponse {
    fileprivate var providerCredentials: ProviderCredentials!

    override var localID: String? { providerCredentials.localID }
    override var federatedID: String? { providerCredentials.federatedID }
    override var providerID: String? { providerCredentials.providerID }
    override var displayName: String? { providerCredentials.displayName }
    override var profile: [String: NSObject]? { googleProfile as [String: NSString] }
    override var username: String? { userName }
    override var idToken: String? { providerCredentials.accessToken }
    override var refreshToken: String? { UserTests.refreshToken }
    override var approximateExpirationDate: Date? {
      Date(timeIntervalSinceNow: accessTokenTimeToLive)
    }
  }

  class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
    fileprivate var providerCredentials: ProviderCredentials!

    override var refreshToken: String { UserTests.refreshToken }
    override var email: String { providerCredentials.email }
    override var idToken: String { providerCredentials.accessToken }
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
      XCTAssertEqual(request.providerIDToken, providerCredentials.idToken)
      XCTAssertEqual(request.providerAccessToken, providerCredentials.accessToken)
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
      response.providerCredentials = providerCredentials
      callback(response, nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, Credentials.apiKey)
      XCTAssertEqual(request.accessToken, providerCredentials.accessToken)

      let response = MockGetAccountInfoResponse()
      response.providerCredentials = providerCredentials
      callback(response, nil)
    }

    override func setAccountInfo(_ request: FIRSetAccountInfoRequest,
                                 callback: @escaping FIRSetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, Credentials.apiKey)
      XCTAssertEqual(request.accessToken, providerCredentials.accessToken)
      XCTAssertNotNil(request.deleteProviders)
      XCTAssertNil(request.email)
      XCTAssertNil(request.localID)
      XCTAssertNil(request.displayName)
      XCTAssertNil(request.photoURL)
      XCTAssertNil(request.password)
      XCTAssertNil(request.providers)
      XCTAssertNil(request.deleteAttributes)

      callback(MockSetAccountInfoResponse(), nil)
    }

    override func verifyPhoneNumber(_ request: FIRVerifyPhoneNumberRequest,
                                    callback: @escaping FIRVerifyPhoneNumberResponseCallback) {
      XCTAssertEqual(request.verificationID, UserTests.verificationID)
      XCTAssertEqual(request.verificationCode, UserTests.verificationCode)
      XCTAssertEqual(request.operation, FIRAuthOperationType.link)
      XCTAssertEqual(request.accessToken, providerCredentials.accessToken)

      let response = MockVerifyPhoneNumberResponse()
      response.providerCredentials = providerCredentials
      callback(response, nil)
    }

    var actionCodeSettings: ActionCodeSettings?
    var getOOBConfirmationCodeError: Error?
    override func getOOBConfirmationCode(_ request: FIRGetOOBConfirmationCodeRequest,
                                         callback: @escaping FIRGetOOBConfirmationCodeResponseCallback) {
      XCTAssertEqual(request.accessToken, UserTests.accessToken)
      XCTAssertEqual(request.continueURL, actionCodeSettings?.url?.absoluteString)
      XCTAssertEqual(request.dynamicLinkDomain, actionCodeSettings?.dynamicLinkDomain)

      if let error = getOOBConfirmationCodeError {
        callback(nil, error)
      } else {
        callback(MockGetOOBConfirmationCodeResponse(), nil)
      }
    }

    override func secureToken(_ request: FIRSecureTokenRequest,
                              callback: @escaping FIRSecureTokenResponseCallback) {
      callback(MockSecureAccessResponse(), nil)
    }
  }

  class MockGetOOBConfirmationCodeResponse: FIRGetOOBConfirmationCodeResponse {
    override var oobCode: String { return UserTests.fakeOOBCode }
  }

  func testlinkAndRetrieveDataSuccess() {
    let facebookCredentials = ProviderCredentials(
      providerID: FacebookAuthProvider.id,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      idToken: nil,
      accessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.accessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] authResult -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProvider.id)

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProvider.id,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          idToken: "GOOGLE_ID_TOKEN",
          accessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail,
          localID: UserTests.localID,
          phoneNumber: nil,
          userInfo: [:]
        )

        authBackend?.providerCredentials = googleCredentials

        let linkGoogleCredential = GoogleAuthProvider.credential(
          withIDToken: googleCredentials.idToken!,
          accessToken: googleCredentials.accessToken
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
                       GoogleAuthProvider.id)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testLinkAndRetrieveDataError() {
    let facebookCredentials = ProviderCredentials(
      providerID: FacebookAuthProvider.id,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      idToken: nil,
      accessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.accessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] authResult -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProvider.id)
        XCTAssertEqual(Auth.auth().currentUser, authResult.user)

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProvider.id,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          idToken: "GOOGLE_ID_TOKEN",
          accessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail,
          localID: UserTests.localID,
          phoneNumber: nil,
          userInfo: [:]
        )

        authBackend?.providerCredentials = googleCredentials
        authBackend?
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .accountExistsWithDifferentCredentialError(
              withEmail: UserTests.userName,
              updatedCredential: nil
            ))

        let linkGoogleCredential = GoogleAuthProvider.credential(
          withIDToken: googleCredentials.idToken!,
          accessToken: googleCredentials.accessToken
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
      providerID: FacebookAuthProvider.id,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      idToken: nil,
      accessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.accessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { authResult -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProvider.id)
        XCTAssertEqual(Auth.auth().currentUser, authResult.user)

        authBackend.providerCredentials = facebookCredentials
        authBackend
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .accountExistsWithDifferentCredentialError(
              withEmail: UserTests.userName,
              updatedCredential: nil
            ))

        let linkFacebookCredential = FacebookAuthProvider
          .credential(withAccessToken: facebookCredentials.accessToken)
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
      providerID: FacebookAuthProvider.id,
      federatedID: "FACEBOOK_ID",
      displayName: "Facebook Doe",
      idToken: nil,
      accessToken: "FACEBOOK_ACCESS_TOKEN",
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = facebookCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User associated from a third-party")

    let facebookCredential = FacebookAuthProvider
      .credential(withAccessToken: facebookCredentials.accessToken)

    // when
    Auth.auth()
      .signIn(with: facebookCredential)
      .flatMap { [weak authBackend] authResult -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       FacebookAuthProvider.id)
        XCTAssertEqual(Auth.auth().currentUser, authResult.user)

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProvider.id,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          idToken: "GOOGLE_ID_TOKEN",
          accessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail,
          localID: UserTests.localID,
          phoneNumber: nil,
          userInfo: [:]
        )

        authBackend?.providerCredentials = googleCredentials
        authBackend?
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .userDisabledError(withMessage: nil))

        let linkGoogleCredential = GoogleAuthProvider.credential(
          withIDToken: googleCredentials.idToken!,
          accessToken: googleCredentials.accessToken
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

  func testReauthenticateSuccess() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: EmailAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userReauthenticateExpectation = expectation(description: "User reauthenticated")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<AuthDataResult, Error> in

        let credential = EmailAuthProvider.credential(
          withEmail: UserTests.email,
          password: UserTests.password
        )

        authBackend.providerCredentials.accessToken = UserTests.newAccessToken
        return authResult.user
          .reauthenticate(with: credential)
      }
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authResult in
        let user = authResult.user
        XCTAssertEqual(user.displayName, emailCredentials.displayName)
        XCTAssertEqual(user.email, emailCredentials.email)

        userReauthenticateExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userReauthenticateExpectation], timeout: expectationTimeout)
  }

  func testReauthenticateWithCredentialSuccess() {
    // given
    let googleCredentials = ProviderCredentials(
      providerID: GoogleAuthProvider.id,
      federatedID: "GOOGLE_ID",
      displayName: "Google Doe",
      idToken: "GOOGLE_ID_TOKEN",
      accessToken: "GOOGLE_ACCESS_TOKEN",
      email: UserTests.googleEmail,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = googleCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userReauthenticateExpectation = expectation(description: "User reauthenticated")

    let googleCredential = GoogleAuthProvider.credential(
      withIDToken: googleCredentials.idToken!,
      accessToken: googleCredentials.accessToken
    )

    // when
    Auth.auth()
      .signIn(with: googleCredential)
      .flatMap { authResult -> Future<AuthDataResult, Error> in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       GoogleAuthProvider.id)

        return authResult.user
          .reauthenticate(with: googleCredential)
      }
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authResult in
        XCTAssertEqual(authResult.additionalUserInfo?.profile,
                       UserTests.googleProfile as [String: NSString])
        XCTAssertEqual(authResult.additionalUserInfo?.username,
                       UserTests.userName)
        XCTAssertEqual(authResult.additionalUserInfo?.providerID,
                       GoogleAuthProvider.id)

        userReauthenticateExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userReauthenticateExpectation], timeout: expectationTimeout)
  }

  func testReauthenticateFailure() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: EmailAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userReauthenticateExpectation = expectation(description: "User reauthenticated")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<AuthDataResult, Error> in

        authBackend.providerCredentials.displayName = "New User Doe"
        authBackend.providerCredentials.email = "newEmail"
        authBackend.providerCredentials.localID = "ANOTHER_LOCAL_ID"
        authBackend.providerCredentials.accessToken = "NewAccessToken"

        let credential = EmailAuthProvider.credential(
          withEmail: UserTests.email,
          password: UserTests.password
        )

        return authResult.user
          .reauthenticate(with: credential)
      }
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          // Verify user mismatch error.
          XCTAssertEqual(error.code, AuthErrorCode.userMismatch.rawValue)

          userReauthenticateExpectation.fulfill()
        }
      } receiveValue: { authResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userReauthenticateExpectation], timeout: expectationTimeout)
  }

  func testReauthenticateUserMismatchFailure() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: EmailAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userReauthenticateExpectation = expectation(description: "User reauthenticated")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<AuthDataResult, Error> in

        let googleCredentials = ProviderCredentials(
          providerID: GoogleAuthProvider.id,
          federatedID: "GOOGLE_ID",
          displayName: "Google Doe",
          idToken: "GOOGLE_ID_TOKEN",
          accessToken: "GOOGLE_ACCESS_TOKEN",
          email: UserTests.googleEmail,
          localID: UserTests.localID,
          phoneNumber: nil,
          userInfo: [:]
        )

        authBackend.providerCredentials = googleCredentials
        authBackend
          .verifyAssertionCallback = .failure(FIRAuthErrorUtils
            .userNotFoundError(withMessage: nil))

        let googleCredential = GoogleAuthProvider.credential(
          withIDToken: "GOOGLE_ID_TOKEN",
          accessToken: "GOOGLE_ACCESS_TOKEN"
        )
        return authResult.user
          .reauthenticate(with: googleCredential)
      }
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          // Verify user mismatch error.
          XCTAssertEqual(error.code, AuthErrorCode.userMismatch.rawValue)

          userReauthenticateExpectation.fulfill()
        }
      } receiveValue: { authResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userReauthenticateExpectation], timeout: expectationTimeout)
  }

  func testUnlinkPhoneAuthCredentialSuccess() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: PhoneAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID,
      userInfo: nil
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userUnlinkedExpectation = expectation(description: "User Unlinked")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<AuthDataResult, Error> in

        authBackend.providerCredentials.phoneNumber = Self.phoneNumber
        authBackend.providerCredentials.userInfo = ["providerId": PhoneAuthProvider.id]

        let credential = PhoneAuthProvider.provider()
          .credential(withVerificationID: Self.verificationID,
                      verificationCode: Self.verificationCode)

        return authResult.user
          .link(with: credential)
      }
      .flatMap { authResult -> AnyPublisher<User, Error> in
        XCTAssertEqual(
          Auth.auth().currentUser?.providerData.first?.providerID,
          PhoneAuthProvider.id
        )
        XCTAssertEqual(Auth.auth().currentUser?.phoneNumber, Self.phoneNumber)

        return authResult.user
          .unlink(fromProvider: PhoneAuthProvider.id)
          .eraseToAnyPublisher()
      }
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { user in
        XCTAssertNil(Auth.auth().currentUser?.phoneNumber)

        userUnlinkedExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userUnlinkedExpectation], timeout: expectationTimeout)
  }

  func testSendVerificationEmailSuccess() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: PhoneAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let sentVerificationEmailExpectation = expectation(description: "Sent verification email")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<Void, Error> in
        XCTAssertNotNil(authResult.user)

        return authResult.user
          .sendEmailVerification()
      }
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { _ in

        sentVerificationEmailExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [sentVerificationEmailExpectation], timeout: expectationTimeout)
  }

  func testSendVerificationEmailWithActionCodeSettingsSuccess() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: PhoneAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let sentVerificationEmailExpectation = expectation(description: "Sent verification email")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<Void, Error> in
        XCTAssertNotNil(authResult.user)

        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: UserTests.continueURL)
        actionCodeSettings.dynamicLinkDomain = "example.page.link"
        authBackend.actionCodeSettings = actionCodeSettings

        return authResult.user
          .sendEmailVerification(with: actionCodeSettings)
      }
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { _ in

        sentVerificationEmailExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [sentVerificationEmailExpectation], timeout: expectationTimeout)
  }

  func testSendVerificationEmailInvalidRecipientEmail() {
    // given
    let emailCredentials = ProviderCredentials(
      providerID: PhoneAuthProvider.id,
      federatedID: "EMAIL_ID",
      displayName: "Google Doe",
      idToken: nil,
      accessToken: UserTests.accessToken,
      email: UserTests.email,
      localID: UserTests.localID
    )

    let authBackend = MockAuthBackend()
    authBackend.providerCredentials = emailCredentials
    authBackend.getOOBConfirmationCodeError = FIRAuthErrorUtils
      .invalidRecipientEmailError(withMessage: nil)
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let sentVerificationEmailExpectation = expectation(description: "Sent verification email")

    // when
    Auth.auth()
      .signIn(withEmail: UserTests.email, password: UserTests.password)
      .flatMap { authResult -> Future<Void, Error> in
        XCTAssertNotNil(authResult.user)

        return authResult.user
          .sendEmailVerification()
      }
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          // Verify user mismatch error.
          XCTAssertEqual(error.code, AuthErrorCode.invalidRecipientEmail.rawValue)

          sentVerificationEmailExpectation.fulfill()
        }
      } receiveValue: { authResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [sentVerificationEmailExpectation], timeout: expectationTimeout)
  }
}

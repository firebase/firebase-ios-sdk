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

class SignInWithCredentialTests: XCTestCase {
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
  static let googleAccessToken = "GOOGLE_ACCESS_TOKEN"
  static let googleDisplayName = "Google Doe"
  static let googleEmail = "user@gmail.com"
  static let googleProfile: [String: String] = [
    "iss": "https://accounts.google.com\\",
    "email": googleEmail,
    "given_name": "User",
    "family_name": "Doe",
  ]

  static let verificationCode = "12345678"
  static let verificationID = "55432"

  static let fakeEmailSignInlink =
    "https://test.app.goo.gl/?link=https://test.firebaseapp.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://test.apps.com"
  static let fakeOOBCode = "testoobcode"

  class MockEmailLinkSignInResponse: FIREmailLinkSignInResponse {
    override var idToken: String { SignInWithCredentialTests.accessToken }
    override var refreshToken: String { SignInWithCredentialTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: SignInWithCredentialTests.accessTokenTimeToLive)
    }
  }

  class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
    override var idToken: String? { SignInWithCredentialTests.accessToken }
    override var refreshToken: String? { SignInWithCredentialTests.refreshToken }
    override var approximateExpirationDate: Date? {
      Date(timeIntervalSinceNow: SignInWithCredentialTests.accessTokenTimeToLive)
    }
  }

  class MockVerifyAssertionResponse: FIRVerifyAssertionResponse {
    override var federatedID: String? { SignInWithCredentialTests.googleID }
    override var providerID: String? { GoogleAuthProvider.id }
    override var localID: String? { SignInWithCredentialTests.localID }
    override var displayName: String? { SignInWithCredentialTests.displayName }
    override var username: String? { SignInWithCredentialTests.displayName }
    override var profile: [String: NSObject]? {
      SignInWithCredentialTests.googleProfile as [String: NSString]
    }

    override var idToken: String { SignInWithCredentialTests.accessToken }
    override var refreshToken: String { SignInWithCredentialTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: SignInWithCredentialTests.accessTokenTimeToLive)
    }
  }

  class MockVerifyPhoneNumberResponse: FIRVerifyPhoneNumberResponse {
    override var idToken: String? { SignInWithCredentialTests.accessToken }
    override var refreshToken: String? { SignInWithCredentialTests.refreshToken }
    override var approximateExpirationDate: Date? {
      Date(timeIntervalSinceNow: SignInWithCredentialTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String { SignInWithCredentialTests.localID }
    override var email: String { SignInWithCredentialTests.email }
    override var displayName: String { SignInWithCredentialTests.displayName }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    var emailLinkSignInCallback: Result<FIREmailLinkSignInResponse, Error> =
      .success(MockEmailLinkSignInResponse())
    override func emailLinkSignin(_ request: FIREmailLinkSignInRequest,
                                  callback: @escaping FIREmailLinkSigninResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCredentialTests.apiKey)
      XCTAssertEqual(request.email, SignInWithCredentialTests.email)
      XCTAssertEqual(request.oobCode, SignInWithCredentialTests.fakeOOBCode)

      switch emailLinkSignInCallback {
      case let .success(response):
        callback(response, nil)
      case let .failure(error):
        callback(nil, error)
      }
    }

    override func verifyPhoneNumber(_ request: FIRVerifyPhoneNumberRequest,
                                    callback: @escaping FIRVerifyPhoneNumberResponseCallback) {
      XCTAssertEqual(request.verificationCode, SignInWithCredentialTests.verificationCode)
      XCTAssertEqual(request.verificationID, SignInWithCredentialTests.verificationID)
      XCTAssertEqual(request.operation, FIRAuthOperationType.signUpOrSignIn)

      let response = MockVerifyPhoneNumberResponse()
      response.isNewUser = true
      callback(response, nil)
    }

    var verifyAssertionCallBack: Result<FIRVerifyAssertionResponse, Error> =
      .success(MockVerifyAssertionResponse())
    override func verifyAssertion(_ request: FIRVerifyAssertionRequest,
                                  callback: @escaping FIRVerifyAssertionResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCredentialTests.apiKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertTrue(request.returnSecureToken)

      switch verifyAssertionCallBack {
      case let .success(response):
        callback(response, nil)
      case let .failure(error):
        callback(nil, error)
      }
    }

    var verifyPasswordCallback: Result<FIRVerifyPasswordResponse, Error> =
      .success(MockVerifyPasswordResponse())
    override func verifyPassword(_ request: FIRVerifyPasswordRequest,
                                 callback: @escaping FIRVerifyPasswordResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCredentialTests.apiKey)
      XCTAssertEqual(request.email, SignInWithCredentialTests.email)
      XCTAssertEqual(request.password, SignInWithCredentialTests.password)
      XCTAssertTrue(request.returnSecureToken)

      switch verifyPasswordCallback {
      case let .success(response):
        callback(response, nil)
      case let .failure(error):
        callback(nil, error)
      }
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, SignInWithCredentialTests.apiKey)
      XCTAssertEqual(request.accessToken, SignInWithCredentialTests.accessToken)
      callback(MockGetAccountInfoResponse(), nil)
    }
  }

  func testSignInWithEmailCredentialSuccess() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    let emailCredential = EmailAuthProvider.credential(
      withEmail: Self.email,
      password: Self.password
    )

    // when
    Auth.auth()
      .signIn(with: emailCredential)
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
        XCTAssertEqual(user.uid, Self.localID)
        XCTAssertEqual(user.displayName, Self.displayName)
        XCTAssertEqual(user.email, Self.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerData.count, 0)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithEmailCredentialFailure() {
    // given
    let authBackend = MockAuthBackend()
    authBackend
      .verifyPasswordCallback = .failure(FIRAuthErrorUtils.userDisabledError(withMessage: nil))
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User disabled")

    let emailCredential = EmailAuthProvider.credential(
      withEmail: Self.email,
      password: Self.password
    )

    // when
    Auth.auth()
      .signIn(with: emailCredential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.userDisabled.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithEmailCredentialEmptyPassword() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User wrong password")

    let emailCredential = EmailAuthProvider.credential(withEmail: Self.email, password: "")

    // when
    Auth.auth()
      .signIn(with: emailCredential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.wrongPassword.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithGoogleAccountExistsError() {
    // given
    let authBackend = MockAuthBackend()
    let mockVerifyAssertionResponse = MockVerifyAssertionResponse()
    mockVerifyAssertionResponse.needConfirmation = true
    authBackend.verifyAssertionCallBack = .success(mockVerifyAssertionResponse)
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User Google exists")

    let googleCredential = GoogleAuthProvider.credential(
      withIDToken: Self.googleID,
      accessToken: Self.googleAccessToken
    )

    // when
    Auth.auth()
      .signIn(with: googleCredential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(
            error.code,
            AuthErrorCode.accountExistsWithDifferentCredential.rawValue
          )

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithGoogleCredentialSuccess() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    let googleCredential = GoogleAuthProvider.credential(
      withIDToken: Self.googleID,
      accessToken: Self.googleAccessToken
    )

    // when
    Auth.auth()
      .signIn(with: googleCredential)
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
        XCTAssertEqual(user.uid, Self.localID)
        XCTAssertEqual(user.displayName, Self.displayName)
        XCTAssertEqual(user.email, Self.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerData.count, 0)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithGoogleCredentialFailure() {
    // given
    let authBackend = MockAuthBackend()
    authBackend
      .verifyAssertionCallBack = .failure(FIRAuthErrorUtils
        .emailAlreadyInUseError(withEmail: nil))
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    let googleCredential = GoogleAuthProvider.credential(
      withIDToken: Self.googleID,
      accessToken: Self.googleAccessToken
    )

    // when
    Auth.auth()
      .signIn(with: googleCredential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.emailAlreadyInUse.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithCredentialSuccess() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    let googleCredential = GoogleAuthProvider.credential(
      withIDToken: Self.googleID,
      accessToken: Self.googleAccessToken
    )

    // when
    Auth.auth()
      .signIn(with: googleCredential)
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
        XCTAssertEqual(user.uid, Self.localID)
        XCTAssertEqual(user.displayName, Self.displayName)
        XCTAssertEqual(user.email, Self.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerData.count, 0)
        XCTAssertEqual(authDataResult.additionalUserInfo?.username, Self.displayName)
        XCTAssertEqual(
          authDataResult.additionalUserInfo?.profile,
          Self.googleProfile as [String: NSString]
        )

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testPhoneAuthSuccess() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    let credential = PhoneAuthProvider.provider()
      .credential(withVerificationID: Self.verificationID,
                  verificationCode: Self.verificationCode)

    // when
    Auth.auth()
      .signIn(with: credential)
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
        XCTAssertEqual(user.uid, Self.localID)
        XCTAssertEqual(user.displayName, Self.displayName)
        XCTAssertEqual(user.email, Self.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerData.count, 0)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testPhoneAuthMissingVerificationCode() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User missing verification code")

    let credential = PhoneAuthProvider.provider()
      .credential(withVerificationID: Self.verificationID, verificationCode: "")

    // when
    Auth.auth()
      .signIn(with: credential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.missingVerificationCode.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testPhoneAuthMissingVerificationID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User missing verification ID")

    let credential = PhoneAuthProvider.provider()
      .credential(withVerificationID: "", verificationCode: Self.verificationCode)

    // when
    Auth.auth()
      .signIn(with: credential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.missingVerificationID.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithEmailLinkCredentialSuccess() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User signed in")

    let emailCrendential = EmailAuthProvider.credential(
      withEmail: Self.email,
      link: Self.fakeEmailSignInlink
    )

    // when
    Auth.auth()
      .signIn(with: emailCrendential)
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
        XCTAssertEqual(user.refreshToken, Self.refreshToken)
        XCTAssertEqual(user.displayName, Self.displayName)
        XCTAssertEqual(user.email, Self.email)
        XCTAssertFalse(user.isAnonymous)

        userSignInExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }

  func testSignInWithEmailLinkCredentialFailure() {
    // given
    let authBackend = MockAuthBackend()
    authBackend
      .emailLinkSignInCallback = .failure(FIRAuthErrorUtils.userDisabledError(withMessage: nil))
    FIRAuthBackend.setBackendImplementation(authBackend)

    var cancellables = Set<AnyCancellable>()
    let userSignInExpectation = expectation(description: "User disabled")

    let emailCrendential = EmailAuthProvider.credential(
      withEmail: Self.email,
      link: Self.fakeEmailSignInlink
    )

    // when
    Auth.auth()
      .signIn(with: emailCrendential)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey])
          XCTAssertEqual(error.code, AuthErrorCode.userDisabled.rawValue)

          userSignInExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [userSignInExpectation], timeout: expectationTimeout)
  }
}

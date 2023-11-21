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

class PasswordResetTests: XCTestCase {
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
  static let fakeEmail = "fakeEmail"
  static let fakeNewEmail = "fakeNewEmail"
  static let fakeCode = "fakeCode"
  static let fakeNewPassword = "fakeNewPassword"
  static let passwordResetRequestType = "PASSWORD_RESET"
  static let verifyEmailRequestType = "VERIFY_EMAIL"

  func testResetPassword() {
    // given
    class MockResetPasswordResponse: FIRResetPasswordResponse {
      override var email: String { return PasswordResetTests.fakeEmail }
    }

    class MockAuthBackend: AuthBackendImplementationMock {
      override func resetPassword(_ request: FIRResetPasswordRequest,
                                  callback: @escaping FIRResetPasswordCallback) {
        XCTAssertEqual(request.apiKey, PasswordResetTests.apiKey)
        XCTAssertEqual(request.oobCode, PasswordResetTests.fakeCode)
        XCTAssertEqual(request.updatedPassword, PasswordResetTests.fakeNewPassword)

        callback(MockResetPasswordResponse(), nil)
      }
    }

    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()

    let confirmPasswordResetExpectation = expectation(description: "Password reset confirmed")

    // when
    Auth.auth()
      .confirmPasswordReset(
        withCode: PasswordResetTests.fakeCode,
        newPassword: PasswordResetTests.fakeNewPassword
      )
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      }, receiveValue: {
        confirmPasswordResetExpectation.fulfill()
      })
      .store(in: &cancellables)

    // then
    wait(for: [confirmPasswordResetExpectation], timeout: expectationTimeout)
  }

  func testVerifyPasswordResetCode() {
    // given
    class MockResetPasswordResponse: FIRResetPasswordResponse {
      override var email: String { return PasswordResetTests.fakeEmail }
      override var requestType: String { return PasswordResetTests.passwordResetRequestType }
    }

    class MockAuthBackend: AuthBackendImplementationMock {
      override func resetPassword(_ request: FIRResetPasswordRequest,
                                  callback: @escaping FIRResetPasswordCallback) {
        XCTAssertEqual(request.apiKey, PasswordResetTests.apiKey)
        XCTAssertEqual(request.oobCode, PasswordResetTests.fakeCode)

        callback(MockResetPasswordResponse(), nil)
      }
    }

    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()

    let verifyPasswordResetCodeExpectation =
      expectation(description: "Password reset code verified")

    // when
    Auth.auth()
      .verifyPasswordResetCode(PasswordResetTests.fakeCode)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { email in
        verifyPasswordResetCodeExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [verifyPasswordResetCodeExpectation], timeout: expectationTimeout)
  }

  func testCheckActionCode() {
    // given
    class MockResetPasswordResponse: FIRResetPasswordResponse {
      override var email: String { return PasswordResetTests.fakeEmail }
      override var verifiedEmail: String { return PasswordResetTests.fakeNewEmail }
      override var requestType: String { return PasswordResetTests.verifyEmailRequestType }
    }

    class MockAuthBackend: AuthBackendImplementationMock {
      override func resetPassword(_ request: FIRResetPasswordRequest,
                                  callback: @escaping FIRResetPasswordCallback) {
        XCTAssertEqual(request.apiKey, PasswordResetTests.apiKey)
        XCTAssertEqual(request.oobCode, PasswordResetTests.fakeCode)

        callback(MockResetPasswordResponse(), nil)
      }
    }

    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()

    let checkActionCodeExpectation = expectation(description: "Action code checked")

    // when
    Auth.auth()
      .checkActionCode(code: PasswordResetTests.fakeCode)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { actionCodeInfo in
        XCTAssertEqual(actionCodeInfo.operation, ActionCodeOperation.verifyEmail)
        XCTAssertEqual(actionCodeInfo.email, PasswordResetTests.fakeNewEmail)
        checkActionCodeExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [checkActionCodeExpectation], timeout: expectationTimeout)
  }

  public func testApplyActionCode() {
    // given
    class MockSetAccountInfoResponse: FIRSetAccountInfoResponse {}

    class MockAuthBackend: AuthBackendImplementationMock {
      override func setAccountInfo(_ request: FIRSetAccountInfoRequest,
                                   callback: @escaping FIRSetAccountInfoResponseCallback) {
        callback(MockSetAccountInfoResponse(), nil)
      }
    }

    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()

    let applyActionCodeExpectation = expectation(description: "Action code applied")

    // when
    Auth.auth()
      .applyActionCode(code: PasswordResetTests.fakeCode)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: {
        applyActionCodeExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [applyActionCodeExpectation], timeout: expectationTimeout)
  }

  func testSendPasswordResetEmail() {
    // given

    class MockAuthBackend: AuthBackendImplementationMock {
      override func getOOBConfirmationCode(_ request: FIRGetOOBConfirmationCodeRequest,
                                           callback: @escaping FIRGetOOBConfirmationCodeResponseCallback) {
        XCTAssertEqual(request.apiKey, PasswordResetTests.apiKey)
        XCTAssertEqual(request.email, PasswordResetTests.fakeEmail)
        callback(FIRGetOOBConfirmationCodeResponse(), nil)
      }
    }

    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()

    let sendPasswordResetExpectation = expectation(description: "Password reset sent")

    // when
    Auth.auth()
      .sendPasswordReset(withEmail: PasswordResetTests.fakeEmail)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: {
        sendPasswordResetExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [sendPasswordResetExpectation], timeout: expectationTimeout)
  }
}

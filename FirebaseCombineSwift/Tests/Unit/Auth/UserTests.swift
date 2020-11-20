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

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseCombineSwift
import Combine
import XCTest

private class MockAuthBackend: AuthBackendImplementationMock {
  var localId: String
  var displayName: String
  var email: String
  var passwordHash: String

  init(withLocalId localId: String, displayName: String, email: String, passwordHash: String) {
    self.localId = localId
    self.displayName = displayName
    self.email = email
    self.passwordHash = passwordHash
  }

  override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                               callback: @escaping FIRGetAccountInfoResponseCallback) {
    print(#function)
    let response = MockGetAccountInfoResponse(
      withLocalId: localId,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash
    )
    callback(response, nil)
  }

  override func signUpNewUser(_ request: FIRSignUpNewUserRequest,
                              callback: @escaping FIRSignupNewUserCallback) {
    print(#function)
    let response = MockSignUpNewUserResponse()
    callback(response, nil)
  }

  override func deleteAccount(_ request: FIRDeleteAccountRequest,
                              callback: @escaping FIRDeleteCallBack) {
    callback(nil)
  }

  override func verifyPassword(_ request: FIRVerifyPasswordRequest,
                               callback: @escaping FIRVerifyPasswordResponseCallback) {
    let response = MockVerifyPasswordResponse()
    callback(response, nil)
  }

  override func secureToken(_ request: FIRSecureTokenRequest,
                            callback: @escaping FIRSecureTokenResponseCallback) {
    let response = MockSecureTokenResponse()
    callback(response, nil)
  }
}

let kEmail = "johnnyappleseed@apple.com"
let kPassword = "secret"
let kLocalId = "LOCAL_ID"
let kDisplayName = "Johnny Appleseed"
let kPasswordHash = "UkVEQUNURUQ="

let expectationTimeout: Double = 2

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

  func configureMockBackend(withLocalId localId: String, displayName: String, email: String,
                            passwordHash: String) {
    let mockBackend = MockAuthBackend(
      withLocalId: localId,
      displayName: displayName,
      email: email,
      passwordHash: passwordHash
    )
    FIRAuthBackend.setBackendImplementation(mockBackend)
  }

  func testCreateUserWithEmailAndPassword() {
    let expect = expectation(description: "User created")
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    let cancellable = Auth.auth()
      .createUser(withEmail: kEmail, password: kPassword)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          print("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, kEmail)

        authDataResult.user.delete { error in
          expect.fulfill()
        }
      }

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  func testSignInUserWithEmailAndPassword() {
    var expect = expectation(description: "User created")
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    var cancellables = Set<AnyCancellable>()

    Auth.auth()
      .createUser(withEmail: kEmail, password: kPassword)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          print("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, kEmail)

        expect.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations(timeout: expectationTimeout, handler: nil)

    expect = expectation(description: "User signed in")

    Auth.auth()
      .signIn(withEmail: kEmail, password: kPassword)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          print("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, kEmail)

        authDataResult.user.delete { error in
          expect.fulfill()
        }
      }
      .store(in: &cancellables)

    waitForExpectations(timeout: expectationTimeout, handler: nil)
  }
}

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
}

class AuthStateDidChangePublisherTests: XCTestCase {
  let expectationTimeout: Double = 2

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

  func testPublisherEmitsWhenAttached() {
    let expect = expectation(description: "Publisher emits value as soon as it is subscribed")
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertNil(user)
        expect.fulfill()
      }

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  func testPublisherEmitsWhenUserIsSignedIn() {
    let expect = expectation(description: "Publisher emits value when user is signed in")
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())

        if let user = user, user.isAnonymous {
          expect.fulfill()
        }
      }

    Auth.auth().signInAnonymously()

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  // Listener should not fire for signing in again.
  func testPublisherDoesNotEmitWhenUserSignsInAgain() {
    var expect = expectation(description: "Publisher emits value when user is signed in")
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())

        if let user = user, user.isAnonymous {
          expect.fulfill()
        }
      }

    // Sign in, expect the publisher to emit
    Auth.auth().signInAnonymously()
    waitForExpectations(timeout: expectationTimeout, handler: nil)

    // Sign in again, expect the publisher NOT to emit
    expect = expectation(description: "Publisher does not emit when user sign in again")
    expect.isInverted = true

    Auth.auth().signInAnonymously()
    waitForExpectations(timeout: expectationTimeout, handler: nil)

    cancellable.cancel()
  }

  // Listener should fire for signing out.
  func testPublisherEmitsWhenUserSignsOut() {
    var expect = expectation(description: "Publisher emits value when user is signed in")
    var shouldUserBeNil = false
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())

        if shouldUserBeNil {
          if user == nil {
            expect.fulfill()
          }
        } else {
          if let user = user, user.isAnonymous {
            expect.fulfill()
          }
        }
      }

    // sign in first
    Auth.auth().signInAnonymously()
    waitForExpectations(timeout: expectationTimeout, handler: nil)

    // now sign out
    expect = expectation(description: "Publisher emits value when user signs out")
    shouldUserBeNil = true
    do {
      try Auth.auth().signOut()
    } catch {}

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  // Listener should no longer fire once detached.
  func testPublisherNoLongerEmitsWhenDetached() {
    var expect = expectation(description: "Publisher emits value when user is signed in")
    var shouldUserBeNil = false
    configureMockBackend(
      withLocalId: kLocalId,
      displayName: kDisplayName,
      email: kEmail,
      passwordHash: kPasswordHash
    )

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())

        if shouldUserBeNil {
          if user == nil {
            expect.fulfill()
          }
        } else {
          if let user = user, user.isAnonymous {
            expect.fulfill()
          }
        }
      }

    // sign in first
    Auth.auth().signInAnonymously()
    waitForExpectations(timeout: expectationTimeout, handler: nil)

    // detach the publisher
    expect = expectation(description: "Publisher no longer emits once detached")
    expect.isInverted = true
    cancellable.cancel()

    shouldUserBeNil = true
    do {
      try Auth.auth().signOut()
    } catch {}

    waitForExpectations(timeout: expectationTimeout, handler: nil)
  }
}

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
import FirebaseCombineSwift
import FirebaseCore
import Foundation
import XCTest

class AuthStateDidChangePublisherTests: XCTestCase {
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
    override var idToken: String { return AuthStateDidChangePublisherTests.accessToken }
    override var refreshToken: String { return AuthStateDidChangePublisherTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: AuthStateDidChangePublisherTests.accessTokenTimeToLive)
    }
  }

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String { return AuthStateDidChangePublisherTests.localID }
    override var email: String { return AuthStateDidChangePublisherTests.email }
    override var displayName: String { return AuthStateDidChangePublisherTests.displayName }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
    override var localID: String { return AuthStateDidChangePublisherTests.localID }
    override var email: String { return AuthStateDidChangePublisherTests.email }
    override var displayName: String { return AuthStateDidChangePublisherTests.displayName }
    override var idToken: String { return AuthStateDidChangePublisherTests.accessToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: AuthStateDidChangePublisherTests.accessTokenTimeToLive)
    }

    override var refreshToken: String { return AuthStateDidChangePublisherTests.refreshToken }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func signUpNewUser(_ request: FIRSignUpNewUserRequest,
                                callback: @escaping FIRSignupNewUserCallback) {
      XCTAssertEqual(request.apiKey, AuthStateDidChangePublisherTests.apiKey)
      XCTAssertNil(request.email)
      XCTAssertNil(request.password)
      XCTAssertTrue(request.returnSecureToken)
      let response = MockSignUpNewUserResponse()
      callback(response, nil)
    }

    override func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                                 callback: @escaping FIRGetAccountInfoResponseCallback) {
      XCTAssertEqual(request.apiKey, AuthStateDidChangePublisherTests.apiKey)
      XCTAssertEqual(request.accessToken, AuthStateDidChangePublisherTests.accessToken)
      let response = MockGetAccountInfoResponse()
      callback(response, nil)
    }

    override func verifyPassword(_ request: FIRVerifyPasswordRequest,
                                 callback: @escaping FIRVerifyPasswordResponseCallback) {
      let response = MockVerifyPasswordResponse()
      callback(response, nil)
    }
  }

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

  func testPublisherEmitsOnMainThread() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    let expect = expectation(description: "Publisher emits on main thread")
    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { user in
        XCTAssertTrue(Thread.isMainThread)
        expect.fulfill()
      }

    Auth.auth().signInAnonymously()

    wait(for: [expect], timeout: expectationTimeout)
    cancellable.cancel()
  }

  func testSubscribersCanReceiveOnNonMainThread() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    let expect = expectation(description: "Subscribers can receive events on non-main threads")
    let cancellable = Auth.auth().authStateDidChangePublisher()
      .receive(on: DispatchQueue.global())
      .sink { user in
        XCTAssertFalse(Thread.isMainThread)
        expect.fulfill()
      }

    Auth.auth().signInAnonymously()

    wait(for: [expect], timeout: expectationTimeout)
    cancellable.cancel()
  }

  func testPublisherEmitsWhenAttached() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    let subscriptionActivatedExpectation =
      expectation(description: "Publisher emits value as soon as it is subscribed")

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { user in
        XCTAssertNil(user)
        subscriptionActivatedExpectation.fulfill()
      }

    wait(for: [subscriptionActivatedExpectation], timeout: expectationTimeout)
    cancellable.cancel()
  }

  func testPublisherEmitsWhenUserIsSignedIn() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    let signedInExpectation =
      expectation(description: "Publisher emits value when user is signed in")
    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { user in
        print("Running on the main thread? \(Thread.isMainThread)")

        if let user, user.isAnonymous {
          signedInExpectation.fulfill()
        }
      }

    Auth.auth().signInAnonymously()

    wait(for: [signedInExpectation], timeout: expectationTimeout)
    cancellable.cancel()
  }

  // Listener should not fire for signing in again.
  func testPublisherDoesNotEmitWhenUserSignsInAgain() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var expect = expectation(description: "Publisher emits value when user is signed in")

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { user in
        if let user, user.isAnonymous {
          expect.fulfill()
        }
      }

    // Sign in, expect the publisher to emit
    Auth.auth().signInAnonymously()
    wait(for: [expect], timeout: expectationTimeout)

    // Sign in again, expect the publisher NOT to emit
    expect = expectation(description: "Publisher does not emit when user sign in again")
    expect.isInverted = true

    Auth.auth().signInAnonymously()
    wait(for: [expect], timeout: expectationTimeout)

    cancellable.cancel()
  }

  // Listener should fire for signing out.
  func testPublisherEmitsWhenUserSignsOut() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var expect = expectation(description: "Publisher emits value when user is signed in")
    var shouldUserBeNil = false

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { user in
        if shouldUserBeNil {
          if user == nil {
            expect.fulfill()
          }
        } else {
          if let user, user.isAnonymous {
            expect.fulfill()
          }
        }
      }

    // sign in first
    Auth.auth().signInAnonymously()
    wait(for: [expect], timeout: expectationTimeout)

    // now sign out
    expect = expectation(description: "Publisher emits value when user signs out")
    shouldUserBeNil = true
    do {
      try Auth.auth().signOut()
    } catch {}

    wait(for: [expect], timeout: expectationTimeout)
    cancellable.cancel()
  }

  // Listener should no longer fire once detached.
  func testPublisherNoLongerEmitsWhenDetached() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var expect = expectation(description: "Publisher emits value when user is signed in")
    var shouldUserBeNil = false

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { user in
        if shouldUserBeNil {
          if user == nil {
            expect.fulfill()
          }
        } else {
          if let user, user.isAnonymous {
            expect.fulfill()
          }
        }
      }

    // sign in first
    Auth.auth().signInAnonymously()
    wait(for: [expect], timeout: expectationTimeout)

    // detach the publisher
    expect = expectation(description: "Publisher no longer emits once detached")
    expect.isInverted = true
    cancellable.cancel()

    shouldUserBeNil = true
    do {
      try Auth.auth().signOut()
    } catch {}

    wait(for: [expect], timeout: expectationTimeout)
  }
}

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

class IDTokenDidChangePublisherTests: XCTestCase {
  static let apiKey = Credentials.apiKey
  static let accessTokenTimeToLive: TimeInterval = 60 * 60
  static let refreshToken = "REFRESH_TOKEN"
  static let accessToken = "ACCESS_TOKEN"

  static let email = "johnnyappleseed@apple.com"
  static let password = "secret"
  static let localID = "LOCAL_ID"
  static let displayName = "Johnny Appleseed"

  class MockGetAccountInfoResponseUser: FIRGetAccountInfoResponseUser {
    override var localID: String { return IDTokenDidChangePublisherTests.localID }
    override var email: String { return IDTokenDidChangePublisherTests.email }
    override var displayName: String { return IDTokenDidChangePublisherTests.displayName }
  }

  class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
    override var users: [FIRGetAccountInfoResponseUser] {
      return [MockGetAccountInfoResponseUser(dictionary: [:])]
    }
  }

  class MockSignUpNewUserResponse: FIRSignUpNewUserResponse {
    override var idToken: String { return IDTokenDidChangePublisherTests.accessToken }
    override var refreshToken: String { return IDTokenDidChangePublisherTests.refreshToken }
    override var approximateExpirationDate: Date {
      Date(timeIntervalSinceNow: IDTokenDidChangePublisherTests.accessTokenTimeToLive)
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
      XCTAssertEqual(request.apiKey, IDTokenDidChangePublisherTests.apiKey)
      XCTAssertEqual(request.accessToken, IDTokenDidChangePublisherTests.accessToken)
      let response = MockGetAccountInfoResponse()
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
      print(#function)
      try Auth.auth().signOut()
    } catch {}
  }

  func testIDTokenChanges() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    //
    // 1) Publisher should emit as soon as it is registered
    var expect = expectation(description: "Publisher emits value as soon as it is subscribed")
    var cancellable = Auth.auth()
      .idTokenDidChangePublisher()
      .sink { user in
        XCTAssertNil(user)
        expect.fulfill()
      }
    wait(for: [expect], timeout: expectationTimeout)
    cancellable.cancel()

    //
    // 2) Publisher should emit when user is signed in
    expect = expectation(description: "Publisher emits value when user is signed in")
    cancellable = Auth.auth()
      .idTokenDidChangePublisher()
      .sink { user in
        if let user, user.isAnonymous {
          expect.fulfill()
        }
      }
    Auth.auth().signInAnonymously()

    wait(for: [expect], timeout: expectationTimeout)
    cancellable.cancel()

    //
    // 3) Publisher should not fire for signing in again
    expect = expectation(description: "Publisher emits value when user is signed in")

    cancellable = Auth.auth()
      .idTokenDidChangePublisher()
      .sink { user in
        if let user, user.isAnonymous {
          print(#function)
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

    //
    // 4) Listener should fire for signing out.
    expect = expectation(description: "Publisher emits value when user is signed in")
    var shouldUserBeNil = false

    cancellable = Auth.auth()
      .idTokenDidChangePublisher()
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

    //
    // Listener should no longer fire once detached.
    expect = expectation(description: "Publisher emits value when user is signed in")
    shouldUserBeNil = false

    cancellable = Auth.auth()
      .idTokenDidChangePublisher()
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

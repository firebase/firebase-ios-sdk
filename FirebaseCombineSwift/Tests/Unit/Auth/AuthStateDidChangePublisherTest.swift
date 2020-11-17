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

class AuthStateDidChangePublisherTest: XCTestCase {
  let expectationTimeout: Double = 2

  override class func setUp() {
    FirebaseApp.configureForTests()
  }

  override func setUp() {
    do {
      try Auth.auth().signOut()
    } catch {}
  }

  func testPublisherEmitsWhenAttached() {
    let expect = expectation(description: "Publisher emits value as soon as it is subscribed")

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertEqual(user, Auth.auth().currentUser)
        XCTAssertNil(user)
        expect.fulfill()
      }

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  func testPublisherEmitsWhenUserIsSignedIn() {
    let expect = expectation(description: "Publisher emits value when user is signed in")

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertEqual(user, Auth.auth().currentUser)

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

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertEqual(user, Auth.auth().currentUser)

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

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertEqual(user, Auth.auth().currentUser)

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

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertEqual(user, Auth.auth().currentUser)

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

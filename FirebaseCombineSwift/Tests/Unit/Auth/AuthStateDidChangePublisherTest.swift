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
  func testPublisherShouldNotEmitForSigningInAgain() {
    let expect = expectation(description: "Publisher should not emit for signing in again")
    var signInCount = 0

    let cancellable = Auth.auth().authStateDidChangePublisher()
      .sink { auth, user in
        XCTAssertEqual(auth, Auth.auth())
        XCTAssertEqual(user, Auth.auth().currentUser)

        if let user = user, user.isAnonymous {
          if signInCount == 2 {
            expect.fulfill()
          }
        }
      }

    signInCount += 1
    Auth.auth().signInAnonymously()

    signInCount += 1
    Auth.auth().signInAnonymously()

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  // Listener should fire for signing out.
  // Listener should no longer fire once detached.
}

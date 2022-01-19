/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import FirebaseAuth
import XCTest

class EmailPasswordTests: TestsBase {
  /// ** The testing email address for testCreateAccountWithEmailAndPassword. */
  let kNewEmailToCreateUser = "user+email_new_user@example.com"

  /// ** The testing email address for testSignInExistingUserWithEmailAndPassword. */
  let kExistingEmailToSignIn = "user+email_existing_user@example.com"

  func testCreateAccountWithEmailAndPassword() {
    let auth = Auth.auth()
    let expectation = self.expectation(description: "Created account with email and password.")
    auth.createUser(withEmail: kNewEmailToCreateUser, password: "password") { result, error in
      if let error = error {
        print("createUserWithEmail has error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
    XCTAssertEqual(auth.currentUser?.email, kNewEmailToCreateUser, "Expected email doesn't match")
    deleteCurrentUser()
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testCreateAccountWithEmailAndPasswordAsync() async throws {
      let auth = Auth.auth()
      try await auth.createUser(withEmail: kNewEmailToCreateUser, password: "password")
      XCTAssertEqual(auth.currentUser?.email, kNewEmailToCreateUser, "Expected email doesn't match")
      try await deleteCurrentUserAsync()
    }
  #endif

  func testSignInExistingUserWithEmailAndPassword() {
    let auth = Auth.auth()
    let expectation = self
      .expectation(description: "Signed in existing account with email and password.")
    auth.signIn(withEmail: kExistingEmailToSignIn, password: "password") { user, error in
      XCTAssertNil(error)
      XCTAssertEqual(auth.currentUser?.email,
                     self.kExistingEmailToSignIn,
                     "Signed user does not match request.")
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testSignInExistingUserWithEmailAndPasswordAsync() async throws {
      let auth = Auth.auth()
      try await auth.signIn(withEmail: kExistingEmailToSignIn, password: "password")
      XCTAssertEqual(auth.currentUser?.email,
                     kExistingEmailToSignIn,
                     "Signed user does not match request.")
    }
  #endif
}

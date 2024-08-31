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

import FirebaseAuth
import Foundation
import XCTest

class EmailPasswordTests: TestsBase {
  /// ** The testing email address for testCreateAccountWithEmailAndPassword. */
  let kNewEmailToCreateUser = "user+email_new_user@example.com"

  /// ** The testing email address for testSignInExistingUserWithEmailAndPassword. */
  let kExistingEmailToSignIn = "user+email_existing_user@example.com"

  func testCreateAccountWithEmailAndPassword() async throws {
    let auth = Auth.auth()
    // Ensure the account that will be created does not already exist.
    let result = try? await auth.signIn(withEmail: kNewEmailToCreateUser, password: "password")
    try? await result?.user.delete()

    let expectation = self.expectation(description: "Created account with email and password.")
    auth.createUser(withEmail: kNewEmailToCreateUser, password: "password") { result, error in
      if let error {
        print("createUserWithEmail has error: \(error)")
      }
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: TestsBase.kExpectationsTimeout)

    XCTAssertEqual(auth.currentUser?.email, kNewEmailToCreateUser, "Expected email doesn't match")
    try? await deleteCurrentUserAsync()
  }

  func testCreateAccountWithEmailAndPasswordAsync() async throws {
    let auth = Auth.auth()
    // Ensure the account that will be created does not already exist.
    let result = try? await auth.signIn(withEmail: kNewEmailToCreateUser, password: "password")
    try? await result?.user.delete()

    try await auth.createUser(withEmail: kNewEmailToCreateUser, password: "password")
    XCTAssertEqual(auth.currentUser?.email, kNewEmailToCreateUser, "Expected email doesn't match")
    try await deleteCurrentUserAsync()
  }

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

  func testSignInExistingUserWithEmailAndPasswordAsync() async throws {
    let auth = Auth.auth()
    try await auth.signIn(withEmail: kExistingEmailToSignIn, password: "password")
    XCTAssertEqual(auth.currentUser?.email,
                   kExistingEmailToSignIn,
                   "Signed user does not match request.")
    // Regression test for #13550. Auth enumeration protection is enabled for
    // the test project, so no sign in methods should be returned.
    let signInMethods = try await auth.fetchSignInMethods(forEmail: kExistingEmailToSignIn)
    XCTAssertEqual(signInMethods, [])
  }
}

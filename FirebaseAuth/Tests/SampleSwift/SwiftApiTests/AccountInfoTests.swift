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
import XCTest

class AccountInfoTests: TestsBase {
  /** A unique testing email address per test run to avoid parallel-job collisions. */
  private var oldUserEmail: String!

  override func setUp() {
    super.setUp()
    signOut()
    oldUserEmail = fakeRandomEmail()
    let auth = Auth.auth()
    let expectation1 = expectation(description: "Created account with email and password.")
    auth.createUser(withEmail: oldUserEmail, password: "password") { user, error in
      XCTAssertNil(error)
      expectation1.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }

  override func tearDown() {
    // Clean up the created Firebase user for future runs.
    if let oldUserEmail, Auth.auth().currentUser?.email == oldUserEmail {
      deleteCurrentUser()
    }
    super.tearDown()
  }

  func testUpdatingUsersEmail() {
    let auth = Auth.auth()
    let expectation1 = expectation(description: "Created account with email and password.")
    auth.createUser(withEmail: oldUserEmail, password: "password") { user, error in
      if let error {
        XCTAssertEqual((error as NSError).code,
                       AuthErrorCode.emailAlreadyInUse.rawValue,
                       "Created a user despite it already exiting.")
      } else {
        XCTFail("Did not get error for recreating a user")
      }
      expectation1.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)

    let expectation2 = expectation(description: "Sign in with email and password.")
    auth.signIn(withEmail: oldUserEmail, password: "password") { user, error in
      XCTAssertNil(error)
      XCTAssertEqual(auth.currentUser?.email,
                     self.oldUserEmail,
                     "Signed user does not match request.")
      expectation2.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }

  func testUpdatingUsersEmailAsync() async throws {
    let auth = Auth.auth()
    do {
      _ = try await auth.createUser(withEmail: oldUserEmail, password: "password")
      XCTFail("Did not get error for recreating a user")
    } catch {
      XCTAssertEqual((error as NSError).code,
                     AuthErrorCode.emailAlreadyInUse.rawValue,
                     "Created a user despite it already exiting.")
    }

    let user = try await auth.signIn(withEmail: oldUserEmail, password: "password")
    XCTAssertEqual(user.user.email, oldUserEmail)
    XCTAssertEqual(auth.currentUser?.email,
                   oldUserEmail,
                   "Signed user does not match request.")
  }
}

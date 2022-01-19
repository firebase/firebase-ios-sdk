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

class TestsBase: XCTestCase {
  static let kExpectationsTimeout = 10.0

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func signInAnonymouslyAsync() async throws {
      let auth = Auth.auth()
      try await auth.signInAnonymously()
    }

    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func deleteCurrentUserAsync() async throws {
      let auth = Auth.auth()
      try await auth.currentUser?.delete()
    }
  #endif

  func signInAnonymously() {
    let auth = Auth.auth()

    let expectation = self.expectation(description: "Anonymous sign-in finished.")
    auth.signInAnonymously { result, error in
      if let error = error {
        print("Anonymous sign in error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }

  func signOut() {
    let auth = Auth.auth()
    do {
      try auth.signOut()
    } catch {
      print("Error signing out: \(error)")
    }
  }

  func deleteCurrentUser() {
    let auth = Auth.auth()
    let expectation = self.expectation(description: "Delete current user finished.")
    auth.currentUser?.delete { error in
      if let error = error {
        print("Anonymous sign in error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }
}

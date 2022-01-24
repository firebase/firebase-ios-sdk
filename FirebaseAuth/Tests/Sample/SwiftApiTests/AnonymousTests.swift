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

class AnonymousTests: TestsBase {
  func testUpdatingUsersEmail() {
    signInAnonymously()
    if let isAnonymous = Auth.auth().currentUser?.isAnonymous {
      XCTAssertTrue(isAnonymous)
    } else {
      XCTFail("Missing currentUser after anonymous sign in")
    }
    deleteCurrentUser()
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testUpdatingUsersEmailAsync() async throws {
      try await signInAnonymouslyAsync()
      if let isAnonymous = Auth.auth().currentUser?.isAnonymous {
        XCTAssertTrue(isAnonymous)
      } else {
        XCTFail("Missing currentUser after anonymous sign in")
      }
      try await deleteCurrentUserAsync()
    }
  #endif
}

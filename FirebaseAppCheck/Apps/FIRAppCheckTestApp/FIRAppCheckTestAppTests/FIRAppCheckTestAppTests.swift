// Copyright 2026 Google LLC
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

import AppCheckCore
@testable import FIRAppCheckTestApp
import FirebaseAppCheck
import XCTest

final class FIRAppCheckTestAppTests: XCTestCase {
  var appDelegate: AppDelegate!

  @MainActor
  override func setUp() async throws {
    try await super.setUp()
    appDelegate = try XCTUnwrap(AppDelegate.shared, "AppDelegate.shared is nil")
  }

  func testTokenAcquisitionAndStorageAccess() async throws {
    let token = try await appDelegate.fetchAppCheckToken()
    XCTAssertGreaterThan(token.expirationDate, Date(), "Token should not be expired")
  }

  func testLimitedUseTokenAcquisition() async throws {
    let token = try await appDelegate.requestLimitedUseToken()
    XCTAssertFalse(token.isEmpty, "Limited-use token should not be empty")
  }

  func testCacheWorks() async throws {
    let token1 = try await appDelegate.fetchAppCheckToken().token
    let token2 = try await appDelegate.fetchAppCheckToken().token

    XCTAssertEqual(token1, token2, "Tokens should be identical (cached)")
  }

  func testForceRefresh() async throws {
    let token1 = try await appDelegate.fetchAppCheckToken().token
    let token2 = try await appDelegate.fetchAppCheckToken(forcingRefresh: true).token

    XCTAssertNotEqual(token1, token2, "Tokens should be different after forced refresh")
  }
}

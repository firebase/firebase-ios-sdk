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
  func testTokenAcquisitionAndStorageAccess() throws {
    guard let appDelegate = AppDelegate.shared else {
      XCTFail("AppDelegate.shared is nil")
      return
    }

    let expectation = self.expectation(description: "Token acquisition and storage access")

    appDelegate.requestRecaptchaToken { token, error in
      XCTAssertNotNil(token, "Token should not be nil")
      if let token = token {
        XCTAssertGreaterThan(token.expirationDate, Date(), "Token should not be expired")
      }
      XCTAssertNil(error, "Error should be nil: \(String(describing: error))")
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30, handler: nil)
  }

  func testLimitedUseTokenAcquisition() throws {
    guard let appDelegate = AppDelegate.shared else {
      XCTFail("AppDelegate.shared is nil")
      return
    }

    let expectation = self.expectation(description: "Limited-use token acquisition")

    appDelegate.requestLimitedUseToken { token, error in
      XCTAssertNotNil(token, "Limited-use token should not be nil")
      XCTAssertNil(error, "Error should be nil: \(String(describing: error))")
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30, handler: nil)
  }

  func testCacheWorks() throws {
    guard let appDelegate = AppDelegate.shared else {
      XCTFail("AppDelegate.shared is nil")
      return
    }

    let expectation1 = expectation(description: "First token acquisition")
    var token1: String?

    appDelegate.requestRecaptchaToken { token, error in
      token1 = token?.token
      expectation1.fulfill()
    }

    waitForExpectations(timeout: 30, handler: nil)

    let expectation2 = expectation(description: "Second token acquisition (cached)")
    var token2: String?

    appDelegate.requestRecaptchaToken { token, error in
      token2 = token?.token
      expectation2.fulfill()
    }

    waitForExpectations(timeout: 5, handler: nil) // Short timeout for cache

    XCTAssertNotNil(token1)
    XCTAssertNotNil(token2)
    XCTAssertEqual(token1, token2, "Tokens should be identical (cached)")
  }

  func testForceRefresh() throws {
    guard let appDelegate = AppDelegate.shared else {
      XCTFail("AppDelegate.shared is nil")
      return
    }

    let expectation1 = expectation(description: "First token acquisition")
    var token1: String?

    appDelegate.requestRecaptchaToken { token, error in
      token1 = token?.token
      expectation1.fulfill()
    }

    waitForExpectations(timeout: 30, handler: nil)

    let expectation2 = expectation(description: "Second token acquisition (forced refresh)")

    appDelegate.requestRecaptchaToken(forcingRefresh: true) { token, error in
      XCTAssertNotNil(token, "Token should not be nil")
      XCTAssertNil(error, "Error should be nil")
      XCTAssertNotNil(token1)
      XCTAssertNotEqual(token1, token?.token, "Tokens should be different after forced refresh")
      expectation2.fulfill()
    }

    waitForExpectations(timeout: 30, handler: nil)
  }
}

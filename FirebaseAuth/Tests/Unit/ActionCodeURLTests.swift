// Copyright 2025 Google LLC
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

@testable import FirebaseAuth
import Foundation
import XCTest

/// Unit tests for ActionCodeURL
class ActionCodeURLTests: XCTestCase {
  /// Tests parsing a valid URL with resetPassword mode.
  func testParseURL() {
    let urlString = "https://www.example.com?apiKey=API_KEY&mode=resetPassword&oobCode=OOB_CODE"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertNotNil(actionCodeURL)
    XCTAssertEqual(actionCodeURL?.apiKey, "API_KEY")
    XCTAssertEqual(actionCodeURL?.operation, .passwordReset)
    XCTAssertEqual(actionCodeURL?.code, "OOB_CODE")
  }

  /// Tests parsing an invalid URL.
  func testParseInvalidURL() {
    let urlString = "invalid_url"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertNil(actionCodeURL)
  }

  /// Tests parsing a URL with missing parameters.
  func testParseURLMissingParameters() {
    let urlString = "https://www.example.com"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertNil(actionCodeURL)
  }

  // Tests parsing a URL with an operation and a code.
  func testParseURLDifferentMode() {
    let urlString = "https://www.example.com?apiKey=API_KEY&mode=verifyEmail&oobCode=OOB_CODE"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertNotNil(actionCodeURL)
    XCTAssertEqual(actionCodeURL?.apiKey, "API_KEY")
    XCTAssertEqual(actionCodeURL?.operation, .verifyEmail)
    XCTAssertEqual(actionCodeURL?.code, "OOB_CODE")
  }

  /// Tests parsing a URL with all properties.
  func testParseURLWithAllProperties() {
    let urlString =
      "https://www.example.com?apiKey=API_KEY&mode=recoverEmail&oobCode=OOB_CODE&continueUrl=https://www.continue.com&lang=en"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertNotNil(actionCodeURL)
    XCTAssertEqual(actionCodeURL?.apiKey, "API_KEY")
    XCTAssertEqual(actionCodeURL?.operation, .recoverEmail)
    XCTAssertEqual(actionCodeURL?.code, "OOB_CODE")
    XCTAssertEqual(actionCodeURL?.continueURL?.absoluteString, "https://www.continue.com")
    XCTAssertEqual(actionCodeURL?.languageCode, "en")
  }

  /// Tests parsing a URL with missing oobCode.
  func testParseURLMissingOobCode() {
    let urlString = "https://www.example.com?apiKey=API_KEY&mode=resetPassword"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertNil(actionCodeURL?.code)
  }

  /// Tests parsing a URL with invalid mode.
  func testParseURLInvalidMode() {
    let urlString = "https://www.example.com?apiKey=API_KEY&mode=invalidMode&oobCode=OOB_CODE"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertEqual(actionCodeURL?.operation, .unknown)
  }

  /// Tests parsing a URL with language code.
  func testActionCodeURL_languageCode() {
    let urlString = "https://example.com?lang=fr"
    let actionCodeURL = ActionCodeURL(link: urlString)
    XCTAssertEqual(actionCodeURL?.languageCode, "fr")
  }
}

// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FirebaseAuth
import XCTest

@available(iOS 13, *)
class ExchangeTokenResponseTests: XCTestCase {
  // MARK: - Constants

  let kValidAccessToken = "fake_firebase_token_12345"
  let kValidExpiresIn = 3600
  let kUnexpectedResponseErrorCode = AuthErrorCode.internalError.rawValue

  // MARK: - Test: Successful Initialization

  func testSuccessfulInitialization() {
    let responseDict: [String: AnyHashable] = [
      "accessToken": kValidAccessToken,
      "expiresIn": kValidExpiresIn,
    ]

    do {
      let response = try ExchangeTokenResponse(dictionary: responseDict)
      XCTAssertEqual(response.firebaseToken, kValidAccessToken)
      XCTAssertEqual(Int(response.expiresIn), kValidExpiresIn)

      let expectedExpiration = Date().addingTimeInterval(TimeInterval(kValidExpiresIn))
      let delta = abs(response.expirationDate.timeIntervalSince(expectedExpiration))
      XCTAssertLessThan(delta, 2.0, "Expiration time should be within ~2 seconds")
    } catch {
      XCTFail("Initialization should not fail with valid input. Error: \(error)")
    }
  }

  // MARK: - Test: Missing accessToken

  func testMissingAccessTokenThrows() {
    let responseDict: [String: AnyHashable] = [
      "expiresIn": kValidExpiresIn,
    ]

    XCTAssertThrowsError(try ExchangeTokenResponse(dictionary: responseDict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, kUnexpectedResponseErrorCode)
    }
  }

  // MARK: - Test: Missing expiresIn

  func testMissingExpiresInThrows() {
    let responseDict: [String: AnyHashable] = [
      "accessToken": kValidAccessToken,
    ]

    XCTAssertThrowsError(try ExchangeTokenResponse(dictionary: responseDict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, kUnexpectedResponseErrorCode)
    }
  }

  // MARK: - Test: Invalid expiresIn type

  func testInvalidExpiresInTypeThrows() {
    let responseDict: [String: AnyHashable] = [
      "accessToken": kValidAccessToken,
      "expiresIn": "not-a-number",
    ]

    XCTAssertThrowsError(try ExchangeTokenResponse(dictionary: responseDict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, kUnexpectedResponseErrorCode)
    }
  }

  // MARK: - Test: Invalid accessToken type

  func testInvalidAccessTokenTypeThrows() {
    let responseDict: [String: AnyHashable] = [
      "accessToken": 12345,
      "expiresIn": kValidExpiresIn,
    ]

    XCTAssertThrowsError(try ExchangeTokenResponse(dictionary: responseDict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, kUnexpectedResponseErrorCode)
    }
  }
}

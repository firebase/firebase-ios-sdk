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

#if os(iOS) || os(tvOS) || os(macOS)

  @testable import FirebaseAuth
  import XCTest

  @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
  class FinalizePasskeySignInResponseTests: XCTestCase {
    func makeValidDictionary() -> [String: AnyHashable] {
      return [
        "idToken": "FAKE_ID_TOKEN",
        "refreshToken": "FAKE_REFRESH_TOKEN",
      ]
    }

    func testInitWithValidDictionary() throws {
      let response = try FinalizePasskeySignInResponse(dictionary: makeValidDictionary())
      XCTAssertEqual(response.idToken, "FAKE_ID_TOKEN")
      XCTAssertEqual(response.refreshToken, "FAKE_REFRESH_TOKEN")
    }

    func testInitWithMissingIdToken() {
      var dict = makeValidDictionary()
      dict.removeValue(forKey: "idToken")
      XCTAssertThrowsError(try FinalizePasskeySignInResponse(dictionary: dict)) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }

    func testInitWithMissingRefreshToken() {
      var dict = makeValidDictionary()
      dict.removeValue(forKey: "refreshToken")
      XCTAssertThrowsError(try FinalizePasskeySignInResponse(dictionary: dict)) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }

    func testInitWithEmptyDictionary() {
      let emptyDict: [String: AnyHashable] = [:]
      XCTAssertThrowsError(try FinalizePasskeySignInResponse(dictionary: emptyDict)) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }
  }

#endif

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
  final class StartPasskeySignInResponseTests: XCTestCase {
    private func makeValidDictionary() -> [String: AnyHashable] {
      return [
        "credentialRequestOptions": [
          "rpId": "FAKE_RPID",
          "challenge": "FAKE_CHALLENGE",
        ] as [String: AnyHashable],
      ]
    }

    func testInitWithValidDictionary() throws {
      let dict = makeValidDictionary()
      let response = try StartPasskeySignInResponse(dictionary: dict)
      XCTAssertEqual(response.rpID, "FAKE_RPID")
      XCTAssertEqual(response.challenge, "FAKE_CHALLENGE")
    }

    func testInitWithMissingCredentialRequestOptions() {
      let dict: [String: AnyHashable] = [:]
      XCTAssertThrowsError(try StartPasskeySignInResponse(dictionary: dict)) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }

    func testInitWithMissingRpId() {
      var dict = makeValidDictionary()
      if var options = dict["credentialRequestOptions"] as? [String: AnyHashable] {
        options.removeValue(forKey: "rpId")
        dict["credentialRequestOptions"] = options
      }
      XCTAssertThrowsError(try StartPasskeySignInResponse(dictionary: dict)) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }

    func testInitWithMissingChallenge() {
      var dict = makeValidDictionary()
      if var options = dict["credentialRequestOptions"] as? [String: AnyHashable] {
        options.removeValue(forKey: "challenge")
        dict["credentialRequestOptions"] = options
      }
      XCTAssertThrowsError(try StartPasskeySignInResponse(dictionary: dict)) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }
  }

#endif

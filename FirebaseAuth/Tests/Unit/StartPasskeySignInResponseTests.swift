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

    /// Helper function to remove nested field from dictionary
    private func removeField(_ dict: inout [String: AnyHashable], keyPath: [String]) {
      guard let first = keyPath.first else { return }
      if keyPath.count == 1 {
        dict.removeValue(forKey: first)
      } else if var inDict = dict[first] as? [String: AnyHashable] {
        removeField(&inDict, keyPath: Array(keyPath.dropFirst()))
        dict[first] = inDict
      }
    }

    func testInitWithInvalidDictionary() throws {
      struct TestCase {
        let name: String
        let removeFieldPath: [String]
      }
      let cases: [TestCase] = [
        .init(name: "Missing credential options", removeFieldPath: ["credentialRequestOptions"]),
        .init(name: "Missing rpId", removeFieldPath: ["credentialRequestOptions", "rpId"]),
        .init(
          name: "Missing challenge",
          removeFieldPath: ["credentialRequestOptions", "challenge"]
        ),
      ]
      for testCase in cases {
        var dict = makeValidDictionary()
        removeField(&dict, keyPath: testCase.removeFieldPath)
        XCTAssertThrowsError(try StartPasskeySignInResponse(dictionary: dict),
                             testCase.name) { error in
          let nsError = error as NSError
          XCTAssertEqual(nsError.domain, AuthErrorDomain)
          XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
        }
      }
    }
  }

#endif

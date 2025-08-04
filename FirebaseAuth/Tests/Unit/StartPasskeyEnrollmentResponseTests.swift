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
  class StartPasskeyEnrollmentResponseTests: RPCBaseTests {
    private func makeValidDictionary() -> [String: AnyHashable] {
      return [
        "credentialCreationOptions": [
          "rp": ["id": "FAKE_RP_ID"] as [String: AnyHashable],
          "user": ["id": "FAKE_USER_ID"] as [String: AnyHashable],
          "challenge": "FAKE_CHALLENGE" as String,
        ] as [String: AnyHashable],
      ]
    }

    /// Helper function to remove a nested key from a dictionary
    private func removeField(_ dict: inout [String: AnyHashable], keyPath: [String]) {
      guard let first = keyPath.first else { return }
      if keyPath.count == 1 {
        dict.removeValue(forKey: first)
      } else if var inDict = dict[first] as? [String: AnyHashable] {
        removeField(&inDict, keyPath: Array(keyPath.dropFirst()))
        dict[first] = inDict
      }
    }

    func testInitWithValidDictionary() throws {
      let response = try StartPasskeyEnrollmentResponse(dictionary: makeValidDictionary())
      XCTAssertEqual(response.rpID, "FAKE_RP_ID")
      XCTAssertEqual(response.userID, "FAKE_USER_ID")
      XCTAssertEqual(response.challenge, "FAKE_CHALLENGE")
    }

    func testInitWithMissingFields() throws {
      struct TestCase {
        let name: String
        let removeFieldPath: [String]
      }
      let cases: [TestCase] = [
        .init(name: "Missing rpId", removeFieldPath: ["credentialCreationOptions", "rp", "id"]),
        .init(name: "Missing userId", removeFieldPath: ["credentialCreationOptions", "user", "id"]),
        .init(
          name: "Missing Challenge",
          removeFieldPath: ["credentialCreationOptions", "challenge"]
        ),
      ]
      for testCase in cases {
        var dict = makeValidDictionary()
        removeField(&dict, keyPath: testCase.removeFieldPath)
        XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: dict),
                             testCase.name) { error in
          let nsError = error as NSError
          XCTAssertEqual(nsError.domain, AuthErrorDomain)
          XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
        }
      }
    }

    func testSuccessfulStartPasskeyEnrollmentResponse() async throws {
      let expectedRpID = "FAKE_RP_ID"
      let expectedUserID = "FAKE_USER_ID"
      let expectedChallenge = "FAKE_CHALLENGE"
      rpcIssuer.respondBlock = {
        try self.rpcIssuer.respond(withJSON: [
          "credentialCreationOptions": [
            "rp": ["id": expectedRpID],
            "user": ["id": expectedUserID],
            "challenge": expectedChallenge,
          ],
        ])
      }
      let request = StartPasskeyEnrollmentRequest(
        idToken: "FAKE_ID_TOKEN",
        requestConfiguration: AuthRequestConfiguration(apiKey: "API_KEY", appID: "APP_ID")
      )
      let response = try await authBackend.call(with: request)
      XCTAssertEqual(response.rpID, expectedRpID)
      XCTAssertEqual(response.userID, expectedUserID)
      XCTAssertEqual(response.challenge, expectedChallenge)
    }
  }

#endif

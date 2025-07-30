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
import XCTest

@available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
class StartPasskeyEnrollmentResponseTests: XCTestCase {

  private func makeValidDictionary() -> [String: AnyHashable] {
    return [
      "credentialCreationOptions": [
        "rp": ["id": "example.com"] as [String: AnyHashable],
        "user": ["id": "USER_123"] as [String: AnyHashable],
        "challenge": "FAKE_CHALLENGE" as String
      ] as [String: AnyHashable]
    ]
  }

  func testInitWithValidDictionary() throws {
    let response = try StartPasskeyEnrollmentResponse(dictionary: makeValidDictionary())
    XCTAssertEqual(response.rpID, "example.com")
    XCTAssertEqual(response.userID, "USER_123")
    XCTAssertEqual(response.challenge, "FAKE_CHALLENGE")
  }

  func testInitWithMissingCredentialCreationOptionsThrowsError() {
    let invalidDict: [String: AnyHashable] = [:]
    XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: invalidDict))
  }

  func testInitWithMissingRpThrowsError() {
    var dict = makeValidDictionary()
    if var options = dict["credentialCreationOptions"] as? [String: Any] {
      options.removeValue(forKey: "rp")
      dict["credentialCreationOptions"] = options as? AnyHashable
    }
    XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: dict))
  }

  func testInitWithMissingRpIdThrowsError() {
    var dict = makeValidDictionary()
    if var options = dict["credentialCreationOptions"] as? [String: Any],
       var rp = options["rp"] as? [String: Any] {
      rp.removeValue(forKey: "id")
      options["rp"] = rp
      dict["credentialCreationOptions"] = options as? AnyHashable
    }
    XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: dict))
  }

  func testInitWithMissingUserThrowsError() {
    var dict = makeValidDictionary()
    if var options = dict["credentialCreationOptions"] as? [String: Any] {
      options.removeValue(forKey: "user")
      dict["credentialCreationOptions"] = options as? AnyHashable
    }
    XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: dict))
  }

  func testInitWithMissingUserIdThrowsError() {
    var dict = makeValidDictionary()
    if var options = dict["credentialCreationOptions"] as? [String: Any],
       var user = options["user"] as? [String: Any] {
      user.removeValue(forKey: "id")
      options["user"] = user
      dict["credentialCreationOptions"] = options as? AnyHashable
    }
    XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: dict))
  }

  func testInitWithMissingChallengeThrowsError() {
    var dict = makeValidDictionary()
    if var options = dict["credentialCreationOptions"] as? [String: Any] {
      options.removeValue(forKey: "challenge")
      dict["credentialCreationOptions"] = options as? AnyHashable
    }
    XCTAssertThrowsError(try StartPasskeyEnrollmentResponse(dictionary: dict))
  }
}

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

final class SignInWithSamlIdpResponseTests: XCTestCase {
  private func makeValidDictionary() -> [String: AnyHashable] {
    return [
      "email": "user@example.com",
      "expiresIn": "3600",
      "idToken": "FAKE_ID_TOKEN",
      "providerId": "saml.provider",
      "refreshToken": "FAKE_REFRESH_TOKEN",
    ]
  }

  func testInitWithValidDictionaryAllRequiredFields() throws {
    var dict = makeValidDictionary()
    dict["email"] = "user1@example.com"
    dict["idToken"] = "ID.TOKEN"
    dict["providerId"] = "saml.myidp"
    dict["refreshToken"] = "REFRESH.TOKEN"
    let response = try SignInWithSamlIdpResponse(dictionary: dict)
    XCTAssertEqual(response.email, "user1@example.com")
    XCTAssertEqual(response.idToken, "ID.TOKEN")
    XCTAssertEqual(response.providerId, "saml.myidp")
    XCTAssertEqual(response.refreshToken, "REFRESH.TOKEN")
  }

  func testInitMissingRequiredFields() {
    struct Case { let name: String; let keyToRemove: String }
    let cases: [Case] = [
      .init(name: "Missing email", keyToRemove: "email"),
      .init(name: "Missing expiresIn", keyToRemove: "expiresIn"),
      .init(name: "Missing idToken", keyToRemove: "idToken"),
      .init(name: "Missing providerId", keyToRemove: "providerId"),
      .init(name: "Missing refreshToken", keyToRemove: "refreshToken"),
    ]
    for c in cases {
      var dict = makeValidDictionary()
      dict.removeValue(forKey: c.keyToRemove)
      XCTAssertThrowsError(try SignInWithSamlIdpResponse(dictionary: dict), c.name) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, AuthErrorDomain)
        XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
      }
    }
  }

  func testInitIncorrectFieldTypes() {
    var dict = makeValidDictionary()
    dict["expiresIn"] = 3600
    XCTAssertThrowsError(try SignInWithSamlIdpResponse(dictionary: dict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
    }
    dict = makeValidDictionary()
    dict["idToken"] = 123
    XCTAssertThrowsError(try SignInWithSamlIdpResponse(dictionary: dict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
    }
    dict = makeValidDictionary()
    dict["email"] = NSNull()
    XCTAssertThrowsError(try SignInWithSamlIdpResponse(dictionary: dict)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AuthErrorDomain)
      XCTAssertEqual(nsError.code, AuthErrorCode.internalError.rawValue)
    }
  }
}

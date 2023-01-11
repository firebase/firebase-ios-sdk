// Copyright 2023 Google LLC
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

import Foundation
import XCTest
import FirebaseAuth

final class AuthProviderIDTests: XCTestCase {
  // Verify that AuthProviderID enum values match the class values published for Objective C compatibility.
  func testAuthProviderIDEnumRawValue() {
    XCTAssertEqual(AuthProviderString.apple.rawValue, "apple.com")
    XCTAssertEqual(AuthProviderString.email.rawValue, EmailAuthProvider.id)
    XCTAssertEqual(AuthProviderString.facebook.rawValue, FacebookAuthProvider.id)
    XCTAssertEqual(AuthProviderString.gameCenter.rawValue, GameCenterAuthProvider.id)
    XCTAssertEqual(AuthProviderString.gitHub.rawValue, GitHubAuthProvider.id)
    XCTAssertEqual(AuthProviderString.google.rawValue, GoogleAuthProvider.id)
    XCTAssertEqual(AuthProviderString.phone.rawValue, PhoneAuthProvider.id)
  }
}

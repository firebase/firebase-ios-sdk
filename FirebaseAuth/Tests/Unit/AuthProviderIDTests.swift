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

import FirebaseAuth
import Foundation
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class AuthProviderIDTests: XCTestCase {
  // Verify that AuthProviderID enum values match the class values published for Objective-C
  // compatibility.
  func testAuthProviderIDEnumRawValue() {
    XCTAssertEqual(AuthProviderID.apple.rawValue, "apple.com")
    XCTAssertEqual(AuthProviderID.email.rawValue, EmailAuthProvider.id)
    XCTAssertEqual(AuthProviderID.facebook.rawValue, FacebookAuthProvider.id)
    #if !os(watchOS)
      XCTAssertEqual(AuthProviderID.gameCenter.rawValue, GameCenterAuthProvider.id)
    #endif
    XCTAssertEqual(AuthProviderID.gitHub.rawValue, GitHubAuthProvider.id)
    XCTAssertEqual(AuthProviderID.google.rawValue, GoogleAuthProvider.id)
    XCTAssertEqual(AuthProviderID.phone.rawValue, PhoneAuthProvider.id)
  }
}

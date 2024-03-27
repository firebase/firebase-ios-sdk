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

@testable import FirebaseAuth

/** @class FIREmailAuthProviderTests
    @brief Tests for @c FIREmailAuthProvider
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class EmailAuthProviderTests: XCTestCase {
  /** @fn testEmailAuthCredentialCodingLink
      @brief Tests successful archiving and unarchiving of @c EmailAuthCredential.
   */
  func testEmailAuthCredentialCodingLink() throws {
    let kEmail = "Token"
    let kLink = "Secret"
    let credential = EmailAuthProvider.credential(withEmail: kEmail, link: kLink)
    XCTAssertTrue(EmailAuthCredential.supportsSecureCoding)
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: credential,
      requiringSecureCoding: true
    )
    let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
      ofClass: EmailAuthCredential.self, from: data
    ))
    XCTAssertEqual(unarchivedCredential.email, kEmail)
    switch unarchivedCredential.emailType {
    case .password: XCTFail("Should be a link")
    case let .link(link): XCTAssertEqual(link, kLink)
    }
  }

  /** @fn testEmailAuthCredentialCodingPassword
      @brief Tests successful archiving and unarchiving of @c EmailAuthCredential.
   */
  func testEmailAuthCredentialCodingPassword() throws {
    let kEmail = "Token"
    let kPassword = "password123"
    let credential = EmailAuthProvider.credential(withEmail: kEmail, password: kPassword)
    XCTAssertTrue(EmailAuthCredential.supportsSecureCoding)
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: credential,
      requiringSecureCoding: true
    )
    let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
      ofClass: EmailAuthCredential.self, from: data
    ))
    XCTAssertEqual(unarchivedCredential.email, kEmail)
    switch unarchivedCredential.emailType {
    case let .password(password): XCTAssertEqual(password, kPassword)
    case .link: XCTFail("Should be a password")
    }
  }
}

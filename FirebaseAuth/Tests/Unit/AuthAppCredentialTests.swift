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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthAppCredentialTests: XCTestCase {
  private let kReceipt = "RECEIPT"
  private let kSecret = "SECRET"

  /** @fn testInitializer
      @brief Tests the initializer of the class.
   */
  func testInitializer() {
    let credential = AuthAppCredential(receipt: kReceipt, secret: kSecret)
    XCTAssertEqual(credential.receipt, kReceipt)
    XCTAssertEqual(credential.secret, kSecret)
  }

  /** @fn testSecureCoding
      @brief Tests the implementation of NSSecureCoding protocol.
   */
  func testSecureCoding() throws {
    let credential = AuthAppCredential(receipt: kReceipt, secret: kSecret)
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: credential,
      requiringSecureCoding: true
    )
    let otherCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
      ofClass: AuthAppCredential.self, from: data
    ))
    XCTAssertEqual(otherCredential.receipt, kReceipt)
    XCTAssertEqual(otherCredential.secret, kSecret)
  }
}

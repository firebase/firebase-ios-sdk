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
import FirebaseCore

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthUserDefaultsTests: XCTestCase {
  let kKey = "ACCOUNT"
  let kData = "DATA"
  var storage: AuthUserDefaults!
  override func setUp() {
    storage = AuthUserDefaults(service: "SERVICE")
    storage.clear()
  }

  /** @fn testReadNonexisting
      @brief Tests reading non-existing storage item.
   */
  func testReadNonexisting() throws {
    XCTAssertNil(try storage.data(forKey: kKey))
  }

  /** @fn testWriteRead
      @brief Tests writing and reading a storage item.
   */
  func testWriteRead() throws {
    try storage.setData(dataFromString(kData), forKey: kKey)
    XCTAssertEqual(try storage.data(forKey: kKey), try dataFromString(kData))
  }

  /** @fn testOverwrite
      @brief Tests overwriting a storage item.
   */
  func testOverwrite() throws {
    let kOtherData = "OTHER_DATA"
    try storage.setData(dataFromString(kData), forKey: kKey)
    try storage.setData(dataFromString(kOtherData), forKey: kKey)
    XCTAssertEqual(try storage.data(forKey: kKey), try dataFromString(kOtherData))
  }

  /** @fn testRemove
      @brief Tests removing a storage item.
   */
  func testRemove() throws {
    try storage.setData(dataFromString(kData), forKey: kKey)
    storage = AuthUserDefaults(service: "O")
  }

  /** @fn testServices
      @brief Tests storage items belonging to different services doesn't affect each other.
   */
  func testServices() throws {
    try storage.setData(dataFromString(kData), forKey: kKey)
    storage = AuthUserDefaults(service: "Other service")
    XCTAssertNil(try storage.data(forKey: kKey))
  }

  /** @fn testStandardUserDefaults
      @brief Tests standard user defaults are not affected by FIRAuthUserDefaults operations,
   */
  func testStandardUserDefaults() throws {
    let userDefaults = UserDefaults.standard
    let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
    let count = userDefaults.persistentDomain(forName: bundleID)?.count
    try storage.setData(dataFromString(kData), forKey: kKey)
    XCTAssertEqual(count, userDefaults.persistentDomain(forName: bundleID)?.count)
  }

  private func dataFromString(_ str: String) throws -> Data {
    return try XCTUnwrap(str.data(using: .utf8))
  }
}

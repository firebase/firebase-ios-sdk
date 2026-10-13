// Copyright 2026 Google LLC
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

class AuthInMemoryStorageTests: XCTestCase {
  static let key = "ACCOUNT"
  static let service = "SERVICE"
  static let otherService = "OTHER_SERVICE"
  static let data = Data("DATA".utf8)
  static let otherData = Data("OTHER_DATA".utf8)

  var storage: AuthInMemoryStorage!
  var keychain: AuthKeychainServices!

  override func setUp() {
    super.setUp()
    storage = AuthInMemoryStorage()
    keychain = AuthKeychainServices(service: Self.service, storage: storage)
  }

  func testReadNonexisting() throws {
    XCTAssertNil(try keychain.data(forKey: Self.key))
  }

  func testWriteRead() throws {
    try keychain.setData(Self.data, forKey: Self.key)
    XCTAssertEqual(try keychain.data(forKey: Self.key), Self.data)
  }

  func testOverwrite() throws {
    try keychain.setData(Self.data, forKey: Self.key)
    try keychain.setData(Self.otherData, forKey: Self.key)
    XCTAssertEqual(try keychain.data(forKey: Self.key), Self.otherData)
  }

  func testRemove() throws {
    try keychain.setData(Self.data, forKey: Self.key)
    try keychain.removeData(forKey: Self.key)
    XCTAssertNil(try keychain.data(forKey: Self.key))
  }

  func testRemoveNonexisting() throws {
    XCTAssertNoThrow(try keychain.removeData(forKey: Self.key))
  }

  func testServicesAreIsolated() throws {
    let otherKeychain = AuthKeychainServices(service: Self.otherService, storage: storage)
    try otherKeychain.setData(Self.data, forKey: Self.key)
    XCTAssertNil(try keychain.data(forKey: Self.key))
    XCTAssertEqual(try otherKeychain.data(forKey: Self.key), Self.data)
  }

  func testAccessGroupsAreIsolated() throws {
    let query = accessGroupQuery("GROUP")
    try keychain.setItem(Self.data, withQuery: query)
    XCTAssertEqual(try keychain.getItem(query: query), Self.data)
    XCTAssertNil(try keychain.getItem(query: accessGroupQuery("OTHER_GROUP")))

    try keychain.setItem(Self.otherData, withQuery: query)
    XCTAssertEqual(try keychain.getItem(query: query), Self.otherData)

    try keychain.removeItem(query: query)
    XCTAssertNil(try keychain.getItem(query: query))
  }

  func testAddExistingReturnsDuplicateItem() {
    let query = itemQuery(data: Self.data)
    XCTAssertEqual(storage.add(query: query), noErr)
    XCTAssertEqual(storage.add(query: query), errSecDuplicateItem)
  }

  func testUpdateNonexistingReturnsItemNotFound() {
    XCTAssertEqual(
      storage.update(query: itemQuery(), attributes: [kSecValueData as String: Self.data]),
      errSecItemNotFound
    )
  }

  func testDeleteNonexistingReturnsItemNotFound() {
    XCTAssertEqual(storage.delete(query: itemQuery()), errSecItemNotFound)
  }

  private func itemQuery(data: Data? = nil) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.key,
    ]
    query[kSecValueData as String] = data
    return query
  }

  private func accessGroupQuery(_ accessGroup: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccessGroup as String: accessGroup,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.key,
    ]
  }
}

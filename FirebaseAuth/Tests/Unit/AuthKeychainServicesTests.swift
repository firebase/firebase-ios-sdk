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

// TODO(ncooke3): Add documentation for manually configuring tests on macOS.
#if !os(macOS) || (os(macOS) && FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN)

  import Foundation
  import XCTest

  @testable import FirebaseAuth

  class AuthKeychainServicesTests: XCTestCase {
    static let accountPrefix = "firebase_auth_1_"
    static let key = "ACCOUNT"
    static let service = "SERVICE"
    static let otherService = "OTHER_SERVICE"
    static let data = "DATA"
    static let otherData = "OTHER_DATA"

    static var account: String {
      Self.accountPrefix + Self.key
    }

    func testReadNonexisting() throws {
      setPassword(nil, account: Self.account, service: Self.service)
      setPassword(nil, account: Self.key, service: nil) // Legacy form.
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNil(try keychain.data(forKey: Self.key))
    }

    func testReadExisting() throws {
      setPassword(Self.data, account: Self.account, service: Self.service)
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertEqual(try keychain.data(forKey: Self.key), Self.data.data(using: .utf8))
      deletePassword(account: Self.account, service: Self.service)
    }

    func testNotReadOtherService() throws {
      setPassword(nil, account: Self.account, service: Self.service)
      setPassword(Self.data, account: Self.account, service: Self.otherService)
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNil(try keychain.data(forKey: Self.key))
      deletePassword(account: Self.account, service: Self.otherService)
    }

    func testWriteNonexisting() throws {
      setPassword(nil, account: Self.account, service: Self.service)
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNoThrow(try keychain.setData(Self.data.data(using: .utf8)!, forKey: Self.key))
      XCTAssertEqual(password(for: Self.account, service: Self.service), Self.data)
      deletePassword(account: Self.account, service: Self.service)
    }

    func testWriteExisting() throws {
      setPassword(Self.data, account: Self.account, service: Self.service)
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNoThrow(try keychain.setData(Self.otherData.data(using: .utf8)!, forKey: Self.key))
      XCTAssertEqual(password(for: Self.account, service: Self.service), Self.otherData)
      deletePassword(account: Self.account, service: Self.service)
    }

    func testDeleteNonexisting() {
      setPassword(nil, account: Self.account, service: Self.service)
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNoThrow(try keychain.removeData(forKey: Self.key))
      XCTAssertNil(password(for: Self.account, service: Self.service))
    }

    func testDeleteExisting() throws {
      setPassword(Self.data, account: Self.account, service: Self.service)
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNoThrow(try keychain.removeData(forKey: Self.key))
      XCTAssertNil(password(for: Self.account, service: Self.service))
    }

    func testReadLegacy() throws {
      setPassword(nil, account: Self.account, service: Self.service)
      setPassword(Self.data, account: Self.key, service: nil) // Legacy form.
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertEqual(
        try keychain.data(forKey: Self.key), Self.data.data(using: .utf8)
      )
      // Legacy item should have been moved to current form.
      XCTAssertEqual(
        password(for: Self.account, service: Self.service),
        Self.data
      )
      XCTAssertNil(password(for: Self.key, service: nil), Self.data)
      deletePassword(account: Self.account, service: Self.service)
    }

    func testNotReadLegacy() throws {
      setPassword(Self.data, account: Self.account, service: Self.service)
      setPassword(Self.otherData, account: Self.key, service: nil) // Legacy form.
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertEqual(try keychain.data(forKey: Self.key), Self.data.data(using: .utf8)!)
      // Legacy item should have leave untouched.
      XCTAssertEqual(password(for: Self.account, service: Self.service), Self.data)
      XCTAssertEqual(password(for: Self.key, service: nil), Self.otherData)
      deletePassword(account: Self.account, service: Self.service)
      deletePassword(account: Self.key, service: nil)
    }

    func testRemoveLegacy() throws {
      setPassword(Self.data, account: Self.account, service: Self.service)
      setPassword(Self.otherData, account: Self.key, service: nil) // Legacy form.
      let keychain = AuthKeychainServices(service: Self.service)
      XCTAssertNoThrow(try keychain.removeData(forKey: Self.key))
      XCTAssertNil(password(for: Self.account, service: Self.service))
      XCTAssertNil(password(for: Self.key, service: nil))
    }

    func testNullErrorParameter() throws {
      let keychain = AuthKeychainServices(service: Self.service)
      _ = try keychain.data(forKey: Self.key)
      try keychain.setData(Self.data.data(using: .utf8)!, forKey: Self.key)
      try keychain.removeData(forKey: Self.key)
    }

    // MARK: - Test Helpers

    private func password(for account: String, service: String?) -> String? {
      var query: [CFString: Any] = [
        kSecReturnData: true,
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: account,
      ]

      if let service {
        query[kSecAttrService] = service
      }

      var result: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &result)

      guard let result = result as? Data, status != errSecItemNotFound else {
        return nil
      }

      XCTAssertEqual(status, errSecSuccess)
      return String(data: result, encoding: .utf8)
    }

    private func addPassword(_ password: String,
                             account: String,
                             service: String?) {
      var query: [CFString: Any] = [
        kSecValueData: password.data(using: .utf8)!,
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: account,
      ]
      if let service {
        query[kSecAttrService] = service
      }

      XCTAssertEqual(SecItemAdd(query as CFDictionary, nil), errSecSuccess)
    }

    private func setPassword(_ password: String?,
                             account: String,
                             service: String?) {
      if self.password(for: account, service: service) != nil {
        deletePassword(account: account, service: service)
      }
      if let password {
        addPassword(password, account: account, service: service)
      }
    }

    private func deletePassword(account: String,
                                service: String?) {
      var query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: account,
      ]

      if let service {
        query[kSecAttrService] = service
      }

      XCTAssertEqual(SecItemDelete(query as CFDictionary), errSecSuccess)
    }
  }

#endif // !os(macOS) || (os(macOS) && FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN)

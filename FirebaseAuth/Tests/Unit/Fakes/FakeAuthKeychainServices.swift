// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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
@testable import FirebaseAuth

/// A fake storage instance that imitates the system keychain while storing data in-memory.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class FakeAuthKeychainServices: NSObject, AuthStorage {
  init(service: String) {}

  private static var keychainServices: [String: FakeAuthKeychainServices] = [:]

  private var fakeKeychain: [String: Any] = [:]

  static func storage(identifier: String) -> Self {
    if let existingInstance = keychainServices[identifier] as? Self {
      return existingInstance
    } else {
      let newInstance = Self(service: "FakeAuthKeychainServices")
      keychainServices[identifier] = newInstance
      return newInstance
    }
  }

  func data(forKey key: String) throws -> Data? {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }

    if let data = fakeKeychain[key] as? Data {
      return data
    } else {
      throw AuthErrorUtils.keychainError(
        function: "SecItemCopyMatching",
        status: errSecItemNotFound
      )
    }
  }

  func setData(_ data: Data, forKey key: String) throws {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    fakeKeychain[key] = data
  }

  func removeData(forKey key: String) throws {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }

    guard fakeKeychain[key] != nil else {
      throw AuthErrorUtils.keychainError(
        function: "SecItemDelete",
        status: errSecItemNotFound
      )
    }

    _ = fakeKeychain.removeValue(forKey: key)
  }
}

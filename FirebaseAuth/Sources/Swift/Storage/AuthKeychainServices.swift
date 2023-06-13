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
import FirebaseCoreExtension

/** @var kAccountPrefix
    @brief The prefix string for keychain item account attribute before the key.
    @remarks A number "1" is encoded in the prefix in case we need to upgrade the scheme in future.
 */
private let kAccountPrefix = "firebase_auth_1_"

/** @class FIRAuthKeychain
    @brief The utility class to manipulate data in iOS Keychain.
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class AuthKeychainServices: NSObject, AuthStorage {
  /** @var _service
      @brief The name of the keychain service.
   */
  private let service: String

  /** @var _legacyItemDeletedForKey
      @brief Indicates whether or not this class knows that the legacy item for a particular key has
          been deleted.
      @remarks This dictionary is to avoid unecessary keychain operations against legacy items.
   */

  private var legacyEntryDeletedForKey: Set<String> = []

  static func storage(identifier: String) -> Self {
    return Self(service: identifier)
  }

  init(service: String) {
    self.service = service
  }

  func data(forKey key: String) throws -> Data? {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    if let data = try item(query: genericPasswordQuery(key: key)) {
      return data
    }

    // Check for legacy form.
    if legacyEntryDeletedForKey.contains(key) {
      return nil
    }
    if let data = try item(query: legacyGenericPasswordQuery(key: key)) {
      // Move the data to current form.
      try setData(data, forKey: key)
      deleteLegacyItem(key: key)
      return data
    } else {
      // Mark legacy data as non-existing so we don't have to query it again.
      legacyEntryDeletedForKey.insert(key)
      return nil
    }
  }

  func setData(_ data: Data, forKey key: String) throws {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    try setItem(query: genericPasswordQuery(key: key), attributes: attributes)
  }

  func removeData(forKey key: String) throws {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    try deleteItem(query: genericPasswordQuery(key: key))
    // Legacy form item, if exists, also needs to be removed, otherwise it will be exposed when
    // current form item is removed, leading to incorrect semantics.
    deleteLegacyItem(key: key)
  }

  // MARK: - Private methods for non-sharing keychain operations

  private func item(query: [String: Any]) throws -> Data? {
    var returningQuery = query
    returningQuery[kSecReturnData as String] = true
    returningQuery[kSecReturnAttributes as String] = true

    // Using a match limit of 2 means that we can check whether there is more than one item.
    // If we used a match limit of 1 we would never find out.
    returningQuery[kSecMatchLimit as String] = 2

    var result: AnyObject?
    let status =
      SecItemCopyMatching(returningQuery as CFDictionary, &result)

    if let items = result as? [[String: Any]], status == noErr {
      if items.isEmpty {
        // The keychain query returned no error, but there were no items found.
        throw AuthErrorUtils.keychainError(function: "SecItemCopyMatching", status: status)
      } else if items.count > 1 {
        // More than one keychain item was found, all but the first will be ignored.
        FirebaseLogger.log(
          level: .warning,
          service: "[FirebaseAuth]",
          code: "I-AUT000005",
          message: "Keychain query returned multiple results, all but the first will be ignored: \(items)"
        )
      }

      // Return the non-legacy item.
      for item in items {
        if item[kSecAttrService as String] != nil {
          return item[kSecValueData as String] as? Data
        }
      }

      // If they were all legacy items, just return the first one.
      // This should not happen, since only one account should be
      // stored.
      return items[0][kSecValueData as String] as? Data
    }

    if status == errSecItemNotFound {
      return nil
    } else {
      throw AuthErrorUtils.keychainError(function: "SecItemCopyMatching", status: status)
    }
  }

  private func setItem(query: [String: Any], attributes: [String: Any]) throws {
    let combined = attributes.merging(query, uniquingKeysWith: { _, last in last })
    var hasItem = false

    var status = SecItemAdd(combined as CFDictionary, nil)

    if status == errSecDuplicateItem {
      hasItem = true
      status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }
    if status == noErr {
      return
    }
    let function = hasItem ? "SecItemUpdate" : "SecItemAdd"
    throw AuthErrorUtils.keychainError(function: function, status: status)
  }

  private func deleteItem(query: [String: Any]) throws {
    let status = SecItemDelete(query as CFDictionary)
    if status == noErr || status == errSecItemNotFound {
      return
    }
    throw AuthErrorUtils.keychainError(function: "SecItemDelete", status: status)
  }

  /** @fn deleteLegacyItemsWithKey:
      @brief Deletes legacy item from the keychain if it is not already known to be deleted.
      @param key The key for the item.
   */
  private func deleteLegacyItem(key: String) {
    if legacyEntryDeletedForKey.contains(key) {
      return
    }
    let query = legacyGenericPasswordQuery(key: key)
    SecItemDelete(query as CFDictionary)
    legacyEntryDeletedForKey.insert(key)
  }

  /** @fn genericPasswordQueryWithKey:
      @brief Returns a keychain query of generic password to be used to manipulate key'ed value.
      @param key The key for the value being manipulated, used as the account field in the query.
   */
  private func genericPasswordQuery(key: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: kAccountPrefix + key,
      kSecAttrService as String: service,
    ]
    query[kSecUseDataProtectionKeychain as String] = true
    return query
  }

  /** @fn legacyGenericPasswordQueryWithKey:
      @brief Returns a keychain query of generic password without service field, which is used by
          previous version of this class.
      @param key The key for the value being manipulated, used as the account field in the query.
   */
  private func legacyGenericPasswordQuery(key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
  }
}

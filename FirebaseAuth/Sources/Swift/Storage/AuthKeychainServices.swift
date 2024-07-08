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

import FirebaseCoreExtension
import Foundation

/// The prefix string for keychain item account attribute before the key.
///
/// A number "1" is encoded in the prefix in case we need to upgrade the scheme in future.
private let kAccountPrefix = "firebase_auth_1_"

/// The utility class to manipulate data in iOS Keychain.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class AuthKeychainServices {
  /// The name of the keychain service.
  let service: String

  let keychainStorage: AuthKeychainStorage

  // MARK: - Internal methods for shared keychain operations

  required init(service: String = "Unset service",
                storage: AuthKeychainStorage = AuthKeychainStorageReal()) {
    self.service = service
    keychainStorage = storage
  }

  /// Get the item from keychain by given query.
  /// - Parameter query: The query to query the keychain.
  /// - Returns: The item of the given query.  `nil` if it doesn't  exist.
  func getItem(query: [String: Any]) throws -> Data? {
    var mutableQuery = query
    mutableQuery[kSecReturnData as String] = true
    mutableQuery[kSecReturnAttributes as String] = true
    // Using a match limit of 2 means that we can check whether more than one
    // item is returned by the query.
    mutableQuery[kSecMatchLimit as String] = 2

    var result: AnyObject?
    let status = keychainStorage.get(query: mutableQuery, result: &result)

    if let items = result as? [[String: Any]], status == noErr {
      if items.count != 1 {
        throw AuthErrorUtils.keychainError(function: "SecItemCopyMatching", status: status)
      }

      return items[0][kSecValueData as String] as? Data
    }
    if status == errSecItemNotFound {
      return nil
    } else {
      throw AuthErrorUtils.keychainError(function: "SecItemCopyMatching", status: status)
    }
  }

  /// Set the item into keychain with given query.
  /// - Parameter item: The item to be added into keychain.
  /// - Parameter query: The query to query the keychain.
  /// - Returns: Whether the operation succeed.
  func setItem(_ item: Data, withQuery query: [String: Any]) throws {
    let status: OSStatus
    let function: String
    if try (getItem(query: query)) != nil {
      let attributes: [String: Any] = [kSecValueData as String: item]
      status = keychainStorage.update(query: query, attributes: attributes)
      function = "SecItemUpdate"
    } else {
      var queryWithItem = query
      queryWithItem[kSecValueData as String] = item
      status = keychainStorage.add(query: queryWithItem)
      function = "SecItemAdd"
    }

    if status == noErr {
      return
    }
    throw AuthErrorUtils.keychainError(function: function, status: status)
  }

  /// Remove the item with given queryfrom keychain.
  /// - Parameter query: The query to query the keychain.
  func removeItem(query: [String: Any]) throws {
    let status = keychainStorage.delete(query: query)
    if status == noErr || status == errSecItemNotFound {
      return
    }
    throw AuthErrorUtils.keychainError(function: "SecItemDelete", status: status)
  }

  /// Indicates whether or not this class knows that the legacy item for a particular key has
  /// been deleted.
  ///
  /// This dictionary is to avoid unnecessary keychain operations against legacy items.
  private var legacyEntryDeletedForKey: Set<String> = []

  static func storage(identifier: String) -> Self {
    return Self(service: identifier)
  }

  func data(forKey key: String) throws -> Data? {
    if let data = try getItemLegacy(query: genericPasswordQuery(key: key)) {
      return data
    }

    // Check for legacy form.
    if legacyEntryDeletedForKey.contains(key) {
      return nil
    }
    if let data = try getItemLegacy(query: legacyGenericPasswordQuery(key: key)) {
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
    try setItemLegacy(data, withQuery: genericPasswordQuery(key: key))
  }

  func removeData(forKey key: String) throws {
    try removeItem(query: genericPasswordQuery(key: key))

    // Legacy form item, if exists, also needs to be removed, otherwise it will be exposed when
    // current form item is removed, leading to incorrect semantics.
    deleteLegacyItem(key: key)
  }

  // MARK: - Internal methods for non-sharing keychain operations

  // TODO: This function can go away in favor of `getItem` if we can delete the legacy processing.
  func getItemLegacy(query: [String: Any]) throws -> Data? {
    var returningQuery = query
    returningQuery[kSecReturnData as String] = true
    returningQuery[kSecReturnAttributes as String] = true

    // Using a match limit of 2 means that we can check whether there is more than one item.
    // If we used a match limit of 1 we would never find out.
    returningQuery[kSecMatchLimit as String] = 2

    var result: AnyObject?
    let status = keychainStorage.get(query: returningQuery, result: &result)

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

  // TODO: This function can go away in favor of `setItem` if we can delete the legacy processing.
  func setItemLegacy(_ item: Data, withQuery query: [String: Any]) throws {
    let attributes: [String: Any] = [
      kSecValueData as String: item,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let combined = attributes.merging(query, uniquingKeysWith: { _, last in last })
    var hasItem = false

    var status = keychainStorage.add(query: combined)
    if status == errSecDuplicateItem {
      hasItem = true
      status = keychainStorage.update(query: query, attributes: attributes)
    }
    if status == noErr {
      return
    }
    let function = hasItem ? "SecItemUpdate" : "SecItemAdd"
    throw AuthErrorUtils.keychainError(function: function, status: status)
  }

  /// Deletes legacy item from the keychain if it is not already known to be deleted.
  /// - Parameter key: The key for the item.
  private func deleteLegacyItem(key: String) {
    if legacyEntryDeletedForKey.contains(key) {
      return
    }
    let query = legacyGenericPasswordQuery(key: key)
    keychainStorage.delete(query: query)
    legacyEntryDeletedForKey.insert(key)
  }

  /// Returns a keychain query of generic password to be used to manipulate key'ed value.
  /// - Parameter key: The key for the value being manipulated, used as the account field in the
  /// query.
  private func genericPasswordQuery(key: String) -> [String: Any] {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: kAccountPrefix + key,
      kSecAttrService as String: service,
    ]
    query[kSecUseDataProtectionKeychain as String] = true
    return query
  }

  /// Returns a keychain query of generic password without service field, which is used by
  /// previous version of this class .
  /// - Parameter key: The key for the value being manipulated, used as the account field in the
  /// query.
  private func legacyGenericPasswordQuery(key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
  }
}

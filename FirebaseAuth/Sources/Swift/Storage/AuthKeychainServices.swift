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

/** @var kAccountPrefix
    @brief The prefix string for keychain item account attribute before the key.
    @remarks A number "1" is encoded in the prefix in case we need to upgrade the scheme in future.
 */
private let kAccountPrefix = "firebase_auth_1_"

/** @class FIRAuthKeychain
    @brief The utility class to manipulate data in iOS Keychain.
 */
@objc(FIRAuthKeychainServices) public class AuthKeychainServices: NSObject, AuthStorage {
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

  @objc public init(service: String) {
    self.service = service
  }

  @objc public func data(forKey key: String) throws -> DataWrapper {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    if let data = try item(query: genericPasswordQuery(key: key)).data {
      return DataWrapper(data: data)
    }

    // Check for legacy form.
    if legacyEntryDeletedForKey.contains(key) {
      return DataWrapper(data: nil)
    }
    if let data = try item(query: legacyGenericPasswordQuery(key: key)).data {
      // Move the data to current form.
      try setData(data, forKey: key)
      deleteLegacyItem(key: key)
      return DataWrapper(data: data)
    } else {
      // Mark legacy data as non-existing so we don't have to query it again.
      legacyEntryDeletedForKey.insert(key)
      return DataWrapper(data: nil)
    }
  }

  @objc public func setData(_ data: Data, forKey key: String) throws {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    try setItem(query: genericPasswordQuery(key: key), attributes: attributes)
  }

  @objc public func removeData(forKey key: String) throws {
    if key.isEmpty {
      fatalError("The key cannot be empty.")
    }
    try deleteItem(query: genericPasswordQuery(key: key))
    // Legacy form item, if exists, also needs to be removed, otherwise it will be exposed when
    // current form item is removed, leading to incorrect semantics.
    deleteLegacyItem(key: key)
  }

  // MARK: - Private methods for non-sharing keychain operations

  // TODO(ncooke3): Mark internal after converting corresponding test file to Swift.
  @objc public func item(query: [String: Any]) throws -> DataWrapper {
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

        // XXX TODO: FIRLogWarning is unavailable
        print(
          "I-AUT000005",
          "Keychain query returned multiple results, all but the first will be ignored: \(items)"
        )
//                FIRLogWarning(
//                    kFIRLoggerAuth, "I-AUT000005",
//                    "Keychain query returned multiple results, all but the first will be ignored: %@",
//                    items)
      }

      // Return the non-legacy item.
      for item in items {
        if item[kSecAttrService as String] != nil {
          return DataWrapper(data: item[kSecValueData as String] as? Data)
        }
      }

      // If they were all legacy items, just return the first one.
      // This should not happen, since only one account should be
      // stored.
      return DataWrapper(data: items[0][kSecValueData as String] as? Data)
    }

    if status == errSecItemNotFound {
      return DataWrapper(data: nil)
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
    var query: [String : Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: kAccountPrefix + key,
      kSecAttrService as String: service,
    ]

    #if !FIREBASE_AUTH_MACOS_TESTING
    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *) {
      query[kSecUseDataProtectionKeychain as String] = true
    }
    #endif  // !FIREBASE_AUTH_MACOS_TESTING

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

  // MARK: - Private methods for shared keychain operations

  /** @fn getItemWithQuery:error:
   @brief Get the item from keychain by given query.
   @param query The query to query the keychain.
   @return The item of the given query. nil if not exsit.
   */
  @objc public func getItem(query: [String: Any]) throws -> DataWrapper {
    var mutableQuery = query
    mutableQuery[kSecReturnData as String] = true
    mutableQuery[kSecReturnAttributes as String] = true
    mutableQuery[kSecMatchLimit as String] = 2

    var result: AnyObject?
    let status =
      SecItemCopyMatching(mutableQuery as CFDictionary, &result)

    if let items = result as? [[String: Any]], status == noErr {
      if items.count != 1 {
        throw AuthErrorUtils.keychainError(function: "SecItemCopyMatching", status: status)
      }

      return DataWrapper(data: items[0][kSecValueData as String] as? Data)
    }

    if status == errSecItemNotFound {
      return DataWrapper(data: nil)
    } else {
      throw AuthErrorUtils.keychainError(function: "SecItemCopyMatching", status: status)
    }
  }

  /** @fn setItem:withQuery:error:
   @brief Set the item into keychain with given query.
   @param item The item to be added into keychain.
   @param query The query to query the keychain.
   @return Whether the operation succeed.
   */
  @objc public func setItem(_ item: Data, withQuery query: [String: Any]) throws {
    let status: OSStatus
    let function: String
    if (try getItem(query: query)).data != nil {
      let attributes: [String: Any] = [kSecValueData as String: item]
      status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
      function = "SecItemUpdate"
    } else {
      var queryWithItem = query
      queryWithItem[kSecValueData as String] = item
      status = SecItemAdd(queryWithItem as CFDictionary, nil)
      function = "SecItemAdd"
    }

    if status == noErr {
      return
    }
    throw AuthErrorUtils.keychainError(function: function, status: status)
  }

  /** @fn getItemWithQuery:error:
   @brief Remove the item with given queryfrom keychain.
   @param query The query to query the keychain.
   @return Whether the operation succeed.
   */
  @objc public func removeItem(query: [String: Any]) throws {
    let status = SecItemDelete(query as CFDictionary)
    if status == noErr || status == errSecItemNotFound {
      return
    }
    throw AuthErrorUtils.keychainError(function: "SecItemDelete", status: status)
  }
}

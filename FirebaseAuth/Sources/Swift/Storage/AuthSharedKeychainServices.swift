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

// TODO(ncooke3): Reshape API to conform to `AuthStorage`.
class AuthSharedKeychainServices: NSObject {
  // MARK: - Private methods for shared keychain operations

  /** @fn getItemWithQuery:error:
   @brief Get the item from keychain by given query.
   @param query The query to query the keychain.
   @return The item of the given query. `nil`` if not exist.
   */
  func getItem(query: [String: Any]) throws -> Data? {
    var mutableQuery = query
    mutableQuery[kSecReturnData as String] = true
    mutableQuery[kSecReturnAttributes as String] = true
    // Using a match limit of 2 means that we can check whether more than one
    // item is returned by the query.
    mutableQuery[kSecMatchLimit as String] = 2

    var result: AnyObject?
    let status =
      SecItemCopyMatching(mutableQuery as CFDictionary, &result)

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

  /** @fn setItem:withQuery:error:
   @brief Set the item into keychain with given query.
   @param item The item to be added into keychain.
   @param query The query to query the keychain.
   @return Whether the operation succeed.
   */
  @objc public func setItem(_ item: Data, withQuery query: [String: Any]) throws {
    let status: OSStatus
    let function: String
    if (try getItem(query: query)) != nil {
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

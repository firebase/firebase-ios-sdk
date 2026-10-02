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
import Security

/// Reads and writes Keychain items directly, bypassing the SDK.
///
/// The SDK stores through `GULKeychainStorage`, which maps `kSecAttrService`
/// to its service constant and `kSecAttrAccount` to the raw key string with no
/// hashing or transformation. Probing those attributes directly is therefore a
/// faithful black-box check of where the SDK actually wrote, as opposed to
/// where it reports having written.
enum KeychainProbe {
  /// Builds the generic password query the SDK's storage layer produces.
  private static func query(service: String,
                            account: String,
                            accessGroup: String?) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }
    return query
  }

  /// Returns the raw payload stored at the given address, or `nil` if absent.
  static func data(service: String,
                   account: String,
                   accessGroup: String? = nil) -> Data? {
    var query = query(service: service, account: account, accessGroup: accessGroup)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess else { return nil }
    return result as? Data
  }

  /// Whether an item exists at the given address.
  static func exists(service: String,
                     account: String,
                     accessGroup: String? = nil) -> Bool {
    data(service: service, account: account, accessGroup: accessGroup) != nil
  }

  /// Writes a raw payload to the given address, replacing any existing item.
  ///
  /// Used to seed byte-exact v11 fixtures so the v12 read path can be
  /// exercised without a v11 build.
  @discardableResult
  static func write(_ payload: Data,
                    service: String,
                    account: String,
                    accessGroup: String? = nil) -> Bool {
    remove(service: service, account: account, accessGroup: accessGroup)

    var attributes = query(service: service, account: account, accessGroup: accessGroup)
    attributes[kSecValueData as String] = payload

    return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
  }

  /// Removes the item at the given address, if present.
  @discardableResult
  static func remove(service: String,
                     account: String,
                     accessGroup: String? = nil) -> Bool {
    let status = SecItemDelete(
      query(service: service, account: account, accessGroup: accessGroup) as CFDictionary
    )
    return status == errSecSuccess || status == errSecItemNotFound
  }
}

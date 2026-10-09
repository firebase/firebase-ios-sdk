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

import FirebaseCoreInternal
import Foundation

/// Keeps keychain items in process memory instead of the system keychain.
///
/// Used when `Auth.persistence` is `.inMemory`. Items are lost when the process exits.
final class AuthInMemoryStorage: AuthKeychainStorage {
  static let shared = AuthInMemoryStorage()

  /// The query attributes that identify an item.
  private struct ItemKey: Hashable {
    let accessGroup: String?
    let service: String?
    let account: String?

    init(_ query: [String: Any]) {
      accessGroup = query[kSecAttrAccessGroup as String] as? String
      service = query[kSecAttrService as String] as? String
      account = query[kSecAttrAccount as String] as? String
    }
  }

  private let items = UnfairLock<[ItemKey: Data]>([:])

  func get(query: [String: Any], result: inout AnyObject?) -> OSStatus {
    let key = ItemKey(query)
    guard let data = items.value()[key] else {
      return errSecItemNotFound
    }
    // Match the shape `SecItemCopyMatching` returns for `kSecMatchLimit` > 1 with
    // `kSecReturnData` and `kSecReturnAttributes` set.
    var item: [String: Any] = [kSecValueData as String: data]
    item[kSecAttrService as String] = key.service
    item[kSecAttrAccount as String] = key.account
    result = [item] as AnyObject
    return noErr
  }

  func add(query: [String: Any]) -> OSStatus {
    guard let data = query[kSecValueData as String] as? Data else {
      return errSecParam
    }
    let key = ItemKey(query)
    return items.withLock { items in
      if items[key] != nil {
        return errSecDuplicateItem
      }
      items[key] = data
      return noErr
    }
  }

  func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
    guard let data = attributes[kSecValueData as String] as? Data else {
      return errSecParam
    }
    let key = ItemKey(query)
    return items.withLock { items in
      if items[key] == nil {
        return errSecItemNotFound
      }
      items[key] = data
      return noErr
    }
  }

  @discardableResult func delete(query: [String: Any]) -> OSStatus {
    let key = ItemKey(query)
    return items.withLock { items in
      items.removeValue(forKey: key) == nil ? errSecItemNotFound : noErr
    }
  }
}

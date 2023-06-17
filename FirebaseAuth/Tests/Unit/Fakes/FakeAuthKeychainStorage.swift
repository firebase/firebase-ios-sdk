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
@testable import FirebaseAuth
import XCTest

/** @class AuthKeychainStorage
    @brief The utility class to update the real keychain
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FakeAuthKeychainStorage: AuthKeychainStorage {
  private var fakeKeychain: [String: Any] = [:]

  func get(query: [String: Any], result: inout AnyObject?) -> OSStatus {
    guard let value = fakeKeychain[queryKey(query)] else {
      return errSecItemNotFound
    }
    let returnArrayofDictionary = [[kSecValueData as String: value]]
    result = returnArrayofDictionary as AnyObject
    return noErr
  }

  func add(query: [String: Any]) -> OSStatus {
    fakeKeychain[queryKey(query)] = query[kSecValueData as String]
    return noErr
  }

  func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
    fakeKeychain[queryKey(query)] = query[kSecValueData as String]
    return noErr
  }

  @discardableResult func delete(query: [String: Any]) -> OSStatus {
    fakeKeychain[queryKey(query)] = nil
    return noErr
  }

  private func queryKey(_ query: [String: Any]) -> String {
    do {
      return try XCTUnwrap(query[kSecAttrAccount as String] as? String)
    } catch {
      XCTFail("\(error)")
      return ""
    }
  }
}

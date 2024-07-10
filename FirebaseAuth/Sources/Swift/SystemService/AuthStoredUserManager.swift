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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthStoredUserManager {
  /// Key of user access group stored in user defaults. Used for retrieve the
  /// user access group at launch.
  private static let storedUserAccessGroupKey = "firebase_auth_stored_user_access_group"

  /// Default value for kSecAttrAccount of shared keychain items.
  private static let sharedKeychainAccountValue = "firebase_auth_firebase_user"

  /// The key to encode and decode the stored user.
  private static let storedUserCoderKey = "firebase_auth_stored_user_coder_key"

  /// Mediator object used to access the keychain.
  private let keychainServices: AuthKeychainServices

  /// Mediator object used to access user defaults.
  private let userDefaults: AuthUserDefaults

  /// Designated initializer.
  /// - Parameter serviceName: The service name to initialize with.
  /// - Parameter keychainServices: The keychain manager (or a fake in unit tests)
  init(serviceName: String, keychainServices: AuthKeychainServices) {
    userDefaults = AuthUserDefaults(service: serviceName)
    self.keychainServices = keychainServices
  }

  /// Get the user access group stored locally.
  /// - Returns: The stored user access group; otherwise, `nil`.
  func getStoredUserAccessGroup() -> String? {
    if let data = try? userDefaults.data(forKey: Self.storedUserAccessGroupKey) {
      let userAccessGroup = String(data: data, encoding: .utf8)
      return userAccessGroup
    } else {
      return nil
    }
  }

  /// The setter of the user access group stored locally.
  /// - Parameter accessGroup: The access group to be store.
  func setStoredUserAccessGroup(accessGroup: String?) {
    if let data = accessGroup?.data(using: .utf8) {
      try? userDefaults.setData(data, forKey: Self.storedUserAccessGroupKey)
    } else {
      try? userDefaults.removeData(forKey: Self.storedUserAccessGroupKey)
    }
  }

  // MARK: - User for Access Group

  /// The getter of the user stored locally.
  /// - Parameters:
  ///   - accessGroup: The access group to retrieve the user from.
  ///   - shareAuthStateAcrossDevices: If `true`, the keychain will be synced
  ///    across the end-user's iCloud.
  ///   - projectIdentifier: An identifier of the project that the user
  ///   associates with.
  /// - Returns: The stored user for the given attributes.
  /// - Throws: An error if the operation failed.
  func getStoredUser(accessGroup: String,
                     shareAuthStateAcrossDevices: Bool,
                     projectIdentifier: String) throws -> User? {
    let query = keychainQuery(
      accessGroup: accessGroup,
      shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
      projectIdentifier: projectIdentifier
    )
    guard let data = try keychainServices.getItem(query: query) else {
      return nil
    }
    let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
    return unarchiver.decodeObject(of: User.self, forKey: Self.storedUserCoderKey)
  }

  /// The setter of the user stored locally.
  /// - Parameters:
  ///   - user: The user to be stored.
  ///   - accessGroup: The access group to store the user in.
  ///   - shareAuthStateAcrossDevices: If `true`, the keychain will be
  ///   synced across the end-user's iCloud.
  ///   - projectIdentifier: An identifier of the project that the user
  ///   associates with.
  /// - Throws: An error if the operation failed.
  func setStoredUser(user: User,
                     accessGroup: String,
                     shareAuthStateAcrossDevices: Bool,
                     projectIdentifier: String) throws {
    var query = keychainQuery(
      accessGroup: accessGroup,
      shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
      projectIdentifier: projectIdentifier
    )

    if shareAuthStateAcrossDevices {
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    } else {
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }

    // TODO(ncooke3): The Objective-C code has an #if for watchOS here.
    // Does this work for watchOS?

    let archiver = NSKeyedArchiver(requiringSecureCoding: false)
    archiver.encode(user, forKey: Self.storedUserCoderKey)
    archiver.finishEncoding()

    try keychainServices.setItem(archiver.encodedData, withQuery: query)
  }

  /// Remove the user that stored locally.
  /// - Parameters:
  ///   - accessGroup: The access group to remove the user from.
  ///   - shareAuthStateAcrossDevices: If `true`, the keychain will be
  ///   synced across the end-user's iCloud.
  ///   - projectIdentifier: An identifier of the project that the user
  ///   associates with.
  /// - Throws: An error if the operation failed.
  func removeStoredUser(accessGroup: String,
                        shareAuthStateAcrossDevices: Bool,
                        projectIdentifier: String) throws {
    var query = keychainQuery(
      accessGroup: accessGroup,
      shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
      projectIdentifier: projectIdentifier
    )

    if shareAuthStateAcrossDevices {
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    } else {
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }

    try keychainServices.removeItem(query: query)
  }

  // MARK: - Private Helpers

  private func keychainQuery(accessGroup: String,
                             shareAuthStateAcrossDevices: Bool,
                             projectIdentifier: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccessGroup as String: accessGroup,
      kSecAttrService as String: projectIdentifier,
      kSecAttrAccount as String: Self.sharedKeychainAccountValue,
    ]
    query[kSecUseDataProtectionKeychain as String] = true

    return query
  }
}

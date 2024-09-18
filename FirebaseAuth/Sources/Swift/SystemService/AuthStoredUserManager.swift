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

    // In Firebase 10, the below query contained the `kSecAttrSynchronizable`
    // key set to `true` when `shareAuthStateAcrossDevices == true`. This
    // allows a user entry to be shared across devices via the iCloud keychain.
    // For the purpose of this discussion, such a user entry will be referred
    // to as a "iCloud entry". Conversely, a "non-iCloud entry" will refer to a
    // user entry stored when `shareAuthStateAcrossDevices == false`. Keep in
    // mind that this class exclusively manages user entries stored in
    // device-specific keychain access groups, so both iCloud and non-iCloud
    // entries are implicitly available at the device level to apps that
    // have access rights to the specific keychain access group used.
    //
    // The iCloud/non-iCloud distinction is important because entries stored
    // with `kSecAttrSynchronizable == true` can only be retrieved when the
    // search query includes `kSecAttrSynchronizable == true`. Likewise,
    // entries stored without the `kSecAttrSynchronizable` key (or
    // `kSecAttrSynchronizable == false`) can only be retrieved when
    // the search query omits `kSecAttrSynchronizable` or sets it to `false`.
    //
    // So for each access group, the SDK manages up to two buckets in the
    // keychain, one for iCloud entries and one for non-iCloud entries.
    //
    // From Firebase 11.0.0 up to but not including 11.3.0, the
    // `kSecAttrSynchronizable` key was *not* included in the query when
    // `shareAuthStateAcrossDevices == true`. This had the effect of the iCloud
    // bucket being inaccessible, and iCloud and non-iCloud entries attempting
    // to be written to the same bucket. This was problematic because the
    // two types of entries use another flag, the `kSecAttrAccessible` flag,
    // with different values. If two queries are identical apart from different
    // values for their `kSecAttrAccessible` key, whichever query written to
    // the keychain first won't be accessible for reading or updating via the
    // other query (resulting in a OSStatus of -25300 indicating the queried
    // item cannot be found). And worse, attempting to write the other query to
    // the keychain won't work because the write will conflict with the
    // previously written query (resulting in a OSStatus of -25299 indicating a
    // duplicate item already exists in the keychain). This formed the basis
    // for the issues this bug caused.
    //
    // The missing key was added back in 11.3, but adding back the key
    // introduced a new issue. If the buggy version succeeded at writing an
    // iCloud entry to the non-iCloud bucket (e.g. keychain was empty before
    // iCloud entry was written), then all future non-iCloud writes would fail
    // due to the mismatching `kSecAttrAccessible` flag and throw an
    // unrecoverable error. To address this the below error handling is used to
    // detect such cases, remove the "corrupt" iCloud entry stored by the buggy
    // version in the non-iCloud bucket, and retry writing the current
    // non-iCloud entry again.
    do {
      try keychainServices.setItem(archiver.encodedData, withQuery: query)
    } catch let error as NSError {
      guard shareAuthStateAcrossDevices == false,
            error.localizedFailureReason == "SecItemAdd (-25299)" else {
        // The error is not related to the 11.0 - 11.2 issue described above,
        // and should be rethrown.
        throw error
      }
      // We are trying to write a non-iCloud entry but a corrupt iCloud entry
      // is likely preventing it from happening.
      //
      // The corrupt query was supposed to contain the following keys:
      //   {
      //     kSecAttrSynchronizable: true,
      //     kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
      //   }
      // Instead, it contained:
      //   {
      //     kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
      //   }
      //
      // Excluding `kSecAttrSynchronizable` treats the query as if it's false
      // and the entry won't be shared in iCloud across devices. It is instead
      // written to the non-iCloud bucket. This query is corrupting the
      // non-iCloud bucket because its `kSecAttrAccessible` value is not
      // compatible with the value used for non-iCloud entries. To delete it,
      // a compatible query is formed by swapping the accessibility flag
      // out for `kSecAttrAccessibleAfterFirstUnlock`. This frees up the bucket
      // so the non-iCloud entry can attempt to be written again.
      let corruptQuery = query
        .merging([kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]) { $1 }
      try keychainServices.removeItem(query: corruptQuery)
      try keychainServices.setItem(archiver.encodedData, withQuery: query)
    }
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

    if shareAuthStateAcrossDevices {
      query[kSecAttrSynchronizable as String] = true
    }

    return query
  }
}

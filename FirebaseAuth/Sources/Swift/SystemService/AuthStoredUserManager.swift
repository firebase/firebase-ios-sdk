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

// TODO(ncooke3): Remove this type after all tests and internal call sites are converted to Swift
// This is added since a throwing function returning Optional values in Swift cannot be
// exposed to Objective-C due to convention and meaning of nil values in Objective-C.
// This wrapper allows us to always return a value, thus allowing us to expose Objective-C api.
@objc(FIRUserWrapper) public class UserWrapper: NSObject {
  @objc public let user: User?
  @objc public init(user: User?) {
    self.user = user
  }
}

@objc(FIRAuthStoredUserManager) public class AuthStoredUserManager: NSObject {
  /// Key of user access group stored in user defaults. Used for retrieve the
  /// user access group at launch.
  private static let storedUserAccessGroupKey = "firebase_auth_stored_user_access_group"

  /// Default value for kSecAttrAccount of shared keychain items.
  private static let sharedKeychainAccountValue = "firebase_auth_firebase_user"

  /// The key to encode and decode the stored user.
  private static let storedUserCoderKey = "firebase_auth_stored_user_coder_key"

  // TODO: Should keychainServices be AuthStorage
  /// Mediator object used to access the keychain.
  private let keychainServices: AuthSharedKeychainServices

  /// Mediator object used to access user defaults.
  private let userDefaults: AuthUserDefaults

  /// Designated initializer.
  /// - Parameter serviceName: The service name to initialize with.
  @objc public init(serviceName: String) {
    // TODO: keychainServices should be set by parameter.
    keychainServices = AuthSharedKeychainServices()
    userDefaults = AuthUserDefaults(service: serviceName)
  }

  /// Get the user access group stored locally.
  /// - Returns: The stored user access group; otherwise, `nil`.
  @objc public func getStoredUserAccessGroup() -> String? {
    if let data = try? userDefaults.data(forKey: Self.storedUserAccessGroupKey).data {
      let userAccessGroup = String(data: data, encoding: .utf8)
      return userAccessGroup
    } else {
      return nil
    }
  }

  /// The setter of the user access group stored locally.
  /// - Parameter accessGroup: The access group to be store.
  @objc(setStoredUserAccessGroup:)
  public func setStoredUserAccessGroup(accessGroup: String?) {
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
  @objc(getStoredUserForAccessGroup:shareAuthStateAcrossDevices:projectIdentifier:error:)
  public func getStoredUser(accessGroup: String,
                            shareAuthStateAcrossDevices: Bool,
                            projectIdentifier: String) throws -> UserWrapper {
    let query = keychainQuery(
      accessGroup: accessGroup,
      shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
      projectIdentifier: projectIdentifier
    )

    guard let data = try? keychainServices.getItem(query: query).data else {
      return UserWrapper(user: nil)
    }

    // TODO(ncooke3): The Objective-C code has an #if for watchOS here.
    // Does this work for watchOS?

    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
      return UserWrapper(user: nil)
    }

    let user = unarchiver.decodeObject(of: User.self, forKey: Self.storedUserCoderKey)
    return UserWrapper(user: user)
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
  @objc(setStoredUser:forAccessGroup:shareAuthStateAcrossDevices:projectIdentifier:error:)
  public func setStoredUser(user: User,
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
  @objc(removeStoredUserForAccessGroup:shareAuthStateAcrossDevices:projectIdentifier:error:)
  public func removeStoredUser(accessGroup: String,
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

    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *) {
      query[kSecUseDataProtectionKeychain as String] = true
    }

    return query
  }
}

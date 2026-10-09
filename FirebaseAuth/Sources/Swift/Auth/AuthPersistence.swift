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

import FirebaseCore
import FirebaseCoreInternal
import Foundation

/// Where Firebase Auth stores the signed-in user.
///
/// Set ``Auth/persistence`` before calling `FirebaseApp.configure()`.
public struct AuthPersistence: Sendable, Hashable {
  /// Stores the signed-in user in the keychain, so it survives app restarts. This is the default.
  public static let keychain = AuthPersistence(kind: .keychain)

  /// Keeps the signed-in user in memory only.
  ///
  /// Auth doesn't read from or write to the keychain, and the user is signed out when the process
  /// exits. Use this where the keychain isn't available, such as an XCTest runner process that
  /// fails keychain access with `errSecMissingEntitlement` (-34018). Not intended for use in
  /// production apps.
  public static let inMemory = AuthPersistence(kind: .inMemory)

  private enum Kind: Sendable, Hashable {
    case keychain
    case inMemory
  }

  private let kind: Kind

  private init(kind: Kind) {
    self.kind = kind
  }

  /// The storage backing Auth instances that use this persistence.
  var keychainStorage: AuthKeychainStorage {
    switch kind {
    case .keychain: return AuthKeychainStorageReal.shared
    case .inMemory: return AuthInMemoryStorage.shared
    }
  }
}

private let persistenceLock = UnfairLock(AuthPersistence.keychain)

public extension Auth {
  /// Where Auth instances store the signed-in user. Defaults to ``AuthPersistence/keychain``.
  ///
  /// Set this before calling `FirebaseApp.configure()`. Auth instances are created while
  /// configuring an app and keep the persistence they were created with, so changing it afterward
  /// isn't supported.
  ///
  /// ```swift
  /// if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
  ///   Auth.persistence = .inMemory
  /// }
  /// FirebaseApp.configure()
  /// ```
  static var persistence: AuthPersistence {
    get {
      persistenceLock.value()
    }
    set {
      if let apps = FirebaseApp.allApps, !apps.isEmpty {
        AuthLog.logWarning(
          code: "I-AUT000032",
          message: "Auth.persistence was changed after FirebaseApp.configure(). Existing Auth " +
            "instances keep their current persistence; set it before configuring Firebase."
        )
      }
      persistenceLock.withLock { $0 = newValue }
    }
  }
}

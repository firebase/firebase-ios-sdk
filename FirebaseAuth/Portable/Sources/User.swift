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

private import FirebaseCoreInternal
public import Foundation

/// **[Experimental]** Represents a Firebase Auth user account.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class User: Sendable {
  package struct TokenStorage: Sendable {
    var idToken: String
    var refreshToken: String
    var expirationDate: Date
    weak var auth: Auth?
    var inFlightRefreshTask: Task<String, any Error>?
    var inFlightGeneration: UInt64 = 0
  }

  /// **[Experimental]** The provider's user ID for the user.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let uid: String

  /// **[Experimental]** The user's email address, if available.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let email: String?

  /// **[Experimental]** The name of the user, if available.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let displayName: String?

  /// **[Experimental]** The URL of the user's profile photo, if available.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let photoURL: URL?

  /// **[Experimental]** Indicates whether the user represents an anonymous user.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let isAnonymous: Bool

  /// **[Experimental]** Indicates whether the email address associated with this user has been
  /// verified.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let isEmailVerified: Bool

  private let tokenStorage: UnfairLock<TokenStorage>

  /// **[Experimental]** The current refresh token for the user, if available.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var refreshToken: String? {
    tokenStorage.withLock { $0.refreshToken.isEmpty ? nil : $0.refreshToken }
  }

  package init(uid: String,
               email: String? = nil,
               displayName: String? = nil,
               photoURL: URL? = nil,
               isAnonymous: Bool,
               isEmailVerified: Bool = false,
               idToken: String,
               refreshToken: String,
               expirationDate: Date,
               auth: Auth? = nil) {
    self.uid = uid
    self.email = email
    self.displayName = displayName
    self.photoURL = photoURL
    self.isAnonymous = isAnonymous
    self.isEmailVerified = isEmailVerified
    tokenStorage = UnfairLock(
      TokenStorage(
        idToken: idToken,
        refreshToken: refreshToken,
        expirationDate: expirationDate,
        auth: auth
      )
    )
  }

  /// **[Experimental]** Retrieves the Firebase authentication token, refreshing it if it has
  /// expired.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A valid Firebase Auth ID token string.
  /// - Throws: An error if token refresh fails.
  public func getIDToken() async throws -> String {
    try await getIDToken(forcingRefresh: false)
  }

  /// **[Experimental]** Retrieves the Firebase authentication token, optionally forcing a refresh.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter forcingRefresh: Forces a token refresh even if the current token has not expired.
  /// - Returns: A valid Firebase Auth ID token string.
  /// - Throws: An error if token refresh fails.
  public func getIDToken(forcingRefresh: Bool) async throws -> String {
    let snapshot = currentTokenSnapshot()
    if !forcingRefresh, Auth.isTokenValid(expirationDate: snapshot.expirationDate) {
      return snapshot.idToken
    }
    guard let auth = snapshot.auth else {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Cannot refresh ID token because the owning Auth instance is no longer available."
      )
    }
    return try await auth.refreshToken(for: self, forcingRefresh: forcingRefresh)
  }

  package func currentTokenSnapshot() -> TokenStorage {
    tokenStorage.withLock { $0 }
  }

  package func withTokenStorageLock<R>(_ body: (inout sending TokenStorage) -> sending R)
    -> sending R {
    tokenStorage.withLock(body)
  }

  package func cancelInFlightRefresh() {
    tokenStorage.withLock { state in
      state.inFlightGeneration &+= 1
      state.inFlightRefreshTask?.cancel()
      state.inFlightRefreshTask = nil
    }
  }

  package func updateTokens(idToken: String, refreshToken: String, expirationDate: Date) {
    tokenStorage.withLock { state in
      state.idToken = idToken
      if !refreshToken.isEmpty {
        state.refreshToken = refreshToken
      }
      state.expirationDate = expirationDate
    }
  }
}

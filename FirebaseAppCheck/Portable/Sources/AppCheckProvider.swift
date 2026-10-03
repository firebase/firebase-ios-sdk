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

public import FirebaseCore
import Foundation

/// **[Experimental]** Defines the methods required to be implemented by a specific Firebase App
/// Check provider.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public protocol AppCheckProvider: Sendable {
  /// **[Experimental]** Returns a new Firebase App Check token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A newly minted `AppCheckToken`.
  /// - Throws: An error if the token exchange fails.
  func getToken() async throws -> AppCheckToken

  /// **[Experimental]** Returns a new Firebase App Check token suitable for consumption in a
  /// limited-use scenario.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// If a custom provider does not implement this method, `getToken()` is invoked by default
  /// whenever a limited-use token is requested.
  ///
  /// - Returns: A newly minted limited-use `AppCheckToken`.
  /// - Throws: An error if the token exchange fails.
  func getLimitedUseToken() async throws -> AppCheckToken
}

public extension AppCheckProvider {
  /// **[Experimental]** Default implementation that delegates limited-use token requests to
  /// `getToken()`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A newly minted `AppCheckToken`.
  /// - Throws: An error if `getToken()` fails.
  func getLimitedUseToken() async throws -> AppCheckToken {
    try await getToken()
  }
}

/// **[Experimental]** Defines the interface for classes that can create Firebase App Check
/// providers.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public protocol AppCheckProviderFactory: Sendable {
  /// **[Experimental]** Creates a new instance of a Firebase App Check provider for the specified
  /// application.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter app: The `FirebaseApp` to create the provider for.
  /// - Returns: A new `AppCheckProvider` instance, or `nil` if App Check should not be configured
  ///   for `app`.
  func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)?
}

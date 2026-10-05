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

/// Represents the result of a Firebase App Check token request.
package protocol FIRAppCheckTokenResultInterop: Sendable {
  /// App Check token in the case of success or a placeholder token in the case of a failure.
  ///
  /// In general, the value of the token should always be set to the request header.
  var token: String { get }

  /// A token fetch error in the case of a failure or `nil` in the case of success.
  var error: (any Error)? { get }
}

/// Common methods for Firebase App Check interoperability.
package protocol AppCheckInterop: AnyObject, Sendable {
  /// Retrieves a cached or newly generated Firebase App Check token.
  ///
  /// - Parameter forcingRefresh: If `true`, always generates a new token and updates the cache.
  /// - Returns: A `FIRAppCheckTokenResultInterop` containing the token (or placeholder token on
  ///   failure) and optional error.
  func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop

  /// Retrieves a new limited-use Firebase App Check token.
  ///
  /// - Returns: A `FIRAppCheckTokenResultInterop` containing the limited-use token (or placeholder
  ///   token on failure) and optional error.
  func getLimitedUseToken() async -> any FIRAppCheckTokenResultInterop

  /// The notification name posted to `NotificationCenter.default` each time a Firebase App Check
  /// token is refreshed.
  func tokenDidChangeNotificationName() -> String

  /// `userInfo` key for the App Check token in a notification for
  /// `tokenDidChangeNotificationName()`.
  func notificationTokenKey() -> String

  /// `userInfo` key for the `FirebaseApp.name` in a notification for
  /// `tokenDidChangeNotificationName()`.
  func notificationAppNameKey() -> String
}

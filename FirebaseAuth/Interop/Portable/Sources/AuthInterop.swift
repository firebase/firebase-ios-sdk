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

/// Common methods for Firebase Auth interoperability.
package protocol AuthInterop: AnyObject, Sendable {
  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  ///
  /// - Parameter forcingRefresh: Forces a token refresh even if the current token has not expired.
  /// - Returns: The current user's ID token, or `nil` if no user is signed in.
  /// - Throws: An error if token retrieval or refresh fails.
  func getToken(forcingRefresh: Bool) async throws -> String?

  /// Returns the current Auth user's UID, or `nil` if there is no user signed in.
  func getUserID() -> String?
}

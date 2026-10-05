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

public import Foundation

/// **[Experimental]** An object representing a Firebase App Check token.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class AppCheckToken: Sendable {
  /// **[Experimental]** A Firebase App Check token string.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let token: String

  /// **[Experimental]** The App Check token's expiration date in the device's local time.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let expirationDate: Date

  /// The date when the App Check token was received.
  package let receivedAtDate: Date

  /// **[Experimental]** Creates a Firebase App Check token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameters:
  ///   - token: A Firebase App Check token string.
  ///   - expirationDate: The token's expiration date in the device's local time.
  public convenience init(token: String, expirationDate: Date) {
    self.init(token: token, expirationDate: expirationDate, receivedAtDate: Date())
  }

  /// Creates a Firebase App Check token with an explicit received date.
  ///
  /// - Parameters:
  ///   - token: A Firebase App Check token string.
  ///   - expirationDate: The token's expiration date.
  ///   - receivedAtDate: The date when the token was received.
  package init(token: String, expirationDate: Date, receivedAtDate: Date) {
    self.token = token
    self.expirationDate = expirationDate
    self.receivedAtDate = receivedAtDate
  }
}

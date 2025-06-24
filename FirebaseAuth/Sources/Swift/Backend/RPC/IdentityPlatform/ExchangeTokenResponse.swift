// Copyright 2025 Google LLC
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

// MARK: - ExchangeTokenResponse

/// An internal response containing the result of a successful OIDC token exchange.
///
/// Contains the Firebase ID token and its expiration time.
/// This struct implements `AuthRPCResponse` to parse the JSON payload from the
/// `exchangeOidcToken` endpoint.
@available(iOS 13, *)
struct ExchangeTokenResponse: AuthRPCResponse {
  /// The exchanged firebase access token.
  let firebaseToken: String

  /// The lifetime of the token in seconds.
  let expiresIn: TimeInterval

  /// The calculated date and time when the token expires.
  let expirationDate: Date

  /// Initializes an `ExchangeTokenResponse` by parsing a dictionary from a JSON
  /// payload.
  ///
  /// - Parameter dictionary: The dictionary representing the JSON response from server.
  /// - Throws: `AuthErrorUtils.unexpectedResponse` if the required fields
  ///           (like "idToken", "expiresIn") are missing, have unexpected types
  init(dictionary: [String: AnyHashable]) throws {
    guard let token = dictionary["idToken"] as? String else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    firebaseToken = token
    guard let expiresInString = dictionary["expiresIn"] as? String,
          let expiresInInterval = TimeInterval(expiresInString) else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    expiresIn = expiresInInterval
    expirationDate = Date().addingTimeInterval(expiresIn)
  }
}

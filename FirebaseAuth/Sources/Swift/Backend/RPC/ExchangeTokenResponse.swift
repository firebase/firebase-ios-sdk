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

import Foundation

/// Response containing the new Firebase STS token and its expiration time in seconds.
@available(iOS 13, *)
struct ExchangeTokenResponse: AuthRPCResponse {
    /// The Firebase ID token.
    let firebaseToken: String

    /// The time interval (in *seconds*) until the token expires.
    let expiresIn: TimeInterval

    /// The expiration date of the token, calculated from `expiresInSeconds`.
    let expirationDate: Date

    /// Initializes a new ExchangeTokenResponse from a dictionary.
    ///
    /// - Parameter dictionary: The dictionary representing the JSON response from the server.
    /// - Throws: `AuthErrorUtils.unexpectedResponse` if the dictionary is missing required fields
    ///           or contains invalid data.
    init(dictionary: [String: AnyHashable]) throws {
      guard let token = dictionary["idToken"] as? String else {
                  throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
              }
      self.firebaseToken = token
      expiresIn = (dictionary["expiresIn"] as? TimeInterval) ?? 3600
      expirationDate = Date().addingTimeInterval(expiresIn)
    }
}

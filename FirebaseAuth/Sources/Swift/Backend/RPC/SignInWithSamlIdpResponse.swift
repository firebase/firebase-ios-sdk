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

struct SignInWithSamlIdpResponse: AuthRPCResponse {
  /// The user raw access token.
  let idToken: String
  /// Refresh token for the authenticated user.
  let refreshToken: String
  /// The provider Identifier
  let providerId: String
  /// The email id of user
  let email: String
  /// The calculated date and time when the token expires.
  let expirationDate: Date

  init(dictionary: [String: AnyHashable]) throws {
    guard
      let email = dictionary["email"] as? String,
      let expiration = dictionary["expiresIn"] as? String,
      let idToken = dictionary["idToken"] as? String,
      let providerId = dictionary["providerId"] as? String,
      let refreshToken = dictionary["refreshToken"] as? String
    else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    self.idToken = idToken
    self.refreshToken = refreshToken
    self.providerId = providerId
    self.email = email
    let expiresInSec = TimeInterval(expiration)
    expirationDate = Date().addingTimeInterval(expiresInSec ?? 3600)
  }
}

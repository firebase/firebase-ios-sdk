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

/// Represents the response from the verifyCustomToken endpoint.
struct VerifyCustomTokenResponse: AuthRPCResponse {
  /// Either an authorization code suitable for performing an STS token exchange, or the
  /// access token from Secure Token Service, depending on whether `returnSecureToken` is set
  /// on the request.
  var idToken: String?

  /// The approximate expiration date of the access token.
  var approximateExpirationDate: Date?

  /// The refresh token from Secure Token Service.
  var refreshToken: String?

  /// Flag indicating that the user signing in is a new user and not a returning user.
  var isNewUser: Bool = false

  init(dictionary: [String: AnyHashable]) throws {
    idToken = dictionary["idToken"] as? String
    if let dateString = dictionary["expiresIn"] as? NSString {
      approximateExpirationDate = Date(timeIntervalSinceNow: dateString.doubleValue)
    }
    refreshToken = dictionary["refreshToken"] as? String
    isNewUser = dictionary["isNewUser"] as? Bool ?? false
  }
}

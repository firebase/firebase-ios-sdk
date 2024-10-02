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

/// Represents the provider user info part of the response from the setAccountInfo endpoint.
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/setAccountInfo
class SetAccountInfoResponseProviderUserInfo {
  /// The ID of the identity provider.
  var providerID: String?

  /// The user's display name at the identity provider.
  var displayName: String?

  /// The user's photo URL at the identity provider.
  var photoURL: URL?

  /// Designated initializer.
  /// - Parameter dictionary: The provider user info data from endpoint.
  init(dictionary: [String: Any]) {
    providerID = dictionary["providerId"] as? String
    displayName = dictionary["displayName"] as? String
    if let photoURL = dictionary["photoUrl"] as? String {
      self.photoURL = URL(string: photoURL)
    }
  }
}

/// Represents the response from the setAccountInfo endpoint.
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/setAccountInfo
class SetAccountInfoResponse: AuthRPCResponse {
  required init() {}

  /// The email or the user.
  var email: String?

  /// The display name of the user.
  var displayName: String?

  /// The user's profiles at the associated identity providers.
  var providerUserInfo: [SetAccountInfoResponseProviderUserInfo]?

  /// Either an authorization code suitable for performing an STS token exchange, or the
  /// access token from Secure Token Service, depending on whether `returnSecureToken` is set
  /// on the request.
  var idToken: String?

  /// The approximate expiration date of the access token.
  var approximateExpirationDate: Date?

  /// The refresh token from Secure Token Service.
  var refreshToken: String?

  func setFields(dictionary: [String: AnyHashable]) throws {
    email = dictionary["email"] as? String
    displayName = dictionary["displayName"] as? String
    idToken = dictionary["idToken"] as? String
    if let expiresIn = dictionary["expiresIn"] as? String {
      approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString)
        .doubleValue)
    }
    refreshToken = dictionary["refreshToken"] as? String
    if let providerUserInfoData = dictionary["providerUserInfo"] as? [[String: Any]] {
      providerUserInfo = providerUserInfoData.map { .init(dictionary: $0) }
    }
  }
}

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

private let kExpiresInKey = "expires_in"

/// The key for the refresh token.

private let kRefreshTokenKey = "refresh_token"

/// The key for the access token.

private let kAccessTokenKey = "access_token"

/// The key for the "id_token" value in the response.

private let kIDTokenKey = "id_token"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SecureTokenResponse: AuthRPCResponse {
  required init() {}

  var approximateExpirationDate: Date?
  var refreshToken: String?
  var accessToken: String?
  var idToken: String?

  var expectedKind: String? { nil }

  func setFields(dictionary: [String: AnyHashable]) throws {
    refreshToken = dictionary[kRefreshTokenKey] as? String
    self.accessToken = dictionary[kAccessTokenKey] as? String
    idToken = dictionary[kIDTokenKey] as? String

    guard let accessToken = accessToken else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    guard !accessToken.isEmpty else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    if let expiresIn = dictionary[kExpiresInKey] as? String {
      approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString)
        .doubleValue)
    }
  }
}

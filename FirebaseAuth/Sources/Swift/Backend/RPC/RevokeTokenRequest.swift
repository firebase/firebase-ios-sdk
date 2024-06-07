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

/// The endpoint for the revokeToken request.
private let kRevokeTokenEndpoint = "accounts:revokeToken"

/// The key for the provider that issued the token to revoke.
private let kProviderIDKey = "providerId"

/// The key for the type of the token to revoke.
private let kTokenTypeKey = "tokenType"

/// The key for the token to be revoked.
private let kTokenKey = "token"

/// The key for the ID Token associated with this credential.
private let kIDTokenKey = "idToken"

/// Represents the parameters for the verifyPassword endpoint.
///
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/verifyPassword
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class RevokeTokenRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = RevokeTokenResponse

  /// The provider that issued the token to revoke.
  private(set) var providerID: String

  /// The type of the token to revoke.
  private(set) var tokenType: TokenType

  /// The token to be revoked.
  private(set) var token: String

  /// The ID Token associated with this credential.
  private(set) var idToken: String

  enum TokenType: Int {
    case unspecified = 0, refreshToken = 1, accessToken = 2, authorizationCode = 3
  }

  @available(*, unavailable)
  init(withEndpoint endpoint: String, requestConfiguration: AuthRequestConfiguration) {
    fatalError("Use init(withToken: ... instead")
  }

  init(withToken token: String,
       idToken: String,
       requestConfiguration: AuthRequestConfiguration) {
    // Apple and authorization code are the only provider and token type we support for now.
    // Generalize this initializer to accept other providers and token types once supported.
    providerID = AuthProviderID.apple.rawValue
    tokenType = .authorizationCode
    self.token = token
    self.idToken = idToken
    super.init(endpoint: kRevokeTokenEndpoint,
               requestConfiguration: requestConfiguration,
               useIdentityPlatform: true)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    let body: [String: AnyHashable] = [
      kProviderIDKey: providerID,
      kTokenTypeKey: "\(tokenType.rawValue)",
      kTokenKey: token,
      kIDTokenKey: idToken,
    ]
    return body
  }
}

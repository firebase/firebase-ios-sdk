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

/** @var kRevokeTokenEndpoint
    @brief The endpoint for the revokeToken request.
 */
private let kRevokeTokenEndpoint = "accounts:revokeToken"

/** @var kProviderIDKey
    @brief The key for the provider that issued the token to revoke.
 */
private let kProviderIDKey = "providerId"

/** @var kTokenTypeKey
    @brief The key for the type of the token to revoke.
 */
private let kTokenTypeKey = "tokenType"

/** @var kTokenKey
    @brief The key for the token to be revoked.
 */
private let kTokenKey = "token"

/** @var kIDTokenKey
    @brief The key for the ID Token associated with this credential.
 */
private let kIDTokenKey = "idToken"

/** @class FIRVerifyPasswordRequest
    @brief Represents the parameters for the verifyPassword endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/verifyPassword
 */
@objc(FIRRevokeTokenRequest) public class RevokeTokenRequest: IdentityToolkitRequest,
  AuthRPCRequest {
  /** @property providerID
      @brief The provider that issued the token to revoke.
   */
  @objc public var providerID: String

  /** @property tokenType
      @brief The type of the token to revoke.
   */
  @objc public var tokenType: TokenType

  /** @property token
      @brief The token to be revoked.
   */
  @objc public var token: String

  /** @property idToken
      @brief The ID Token associated with this credential.
   */
  @objc public var idToken: String?

  /** @var response
      @brief The corresponding response for this request
   */
  @objc public var response: AuthRPCResponse = RevokeTokenResponse()

  @objc public enum TokenType: Int {
    case unspecified = 0, refreshToken = 1, accessToken = 2, authorizationCode = 3
  }

  @available(*, unavailable)
  @objc public init(withEndpoint endpoint: String, requestConfiguration: AuthRequestConfiguration) {
    fatalError("Use init(withToken: ... instead")
  }

  @objc public init(withToken token: String,
                    idToken: String?,
                    requestConfiguration: AuthRequestConfiguration) {
    // Apple and authorization code are the only provider and token type we support for now.
    // Generalize this initializer to accept other providers and token types once supported.
    providerID = AuthProviderString.apple.rawValue
    tokenType = .authorizationCode
    self.token = token
    self.idToken = idToken
    super.init(endpoint: kRevokeTokenEndpoint,
               requestConfiguration: requestConfiguration,
               useIdentityPlatform: true,
               useStaging: false)
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    let body: [String: AnyHashable] = [
      kProviderIDKey: providerID,
      kTokenTypeKey: "\(tokenType.rawValue)",
      kTokenKey: token,
      kIDTokenKey: idToken,
    ]
    return body
  }
}

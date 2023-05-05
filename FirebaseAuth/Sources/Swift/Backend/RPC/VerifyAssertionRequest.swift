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

/** @var kVerifyAssertionEndpoint
    @brief The "verifyAssertion" endpoint.
 */
private let kVerifyAssertionEndpoint = "verifyAssertion"

/** @var kProviderIDKey
    @brief The key for the "providerId" value in the request.
 */
private let kProviderIDKey = "providerId"

/** @var kProviderIDTokenKey
    @brief The key for the "id_token" value in the request.
 */
private let kProviderIDTokenKey = "id_token"

/** @var kProviderNonceKey
    @brief The key for the "nonce" value in the request.
 */
private let kProviderNonceKey = "nonce"

/** @var kProviderAccessTokenKey
    @brief The key for the "access_token" value in the request.
 */
private let kProviderAccessTokenKey = "access_token"

/** @var kProviderOAuthTokenSecretKey
    @brief The key for the "oauth_token_secret" value in the request.
 */
private let kProviderOAuthTokenSecretKey = "oauth_token_secret"

/** @var kIdentifierKey
    @brief The key for the "identifier" value in the request.
 */
private let kIdentifierKey = "identifier"

/** @var kRequestURIKey
    @brief The key for the "requestUri" value in the request.
 */
private let kRequestURIKey = "requestUri"

/** @var kPostBodyKey
    @brief The key for the "postBody" value in the request.
 */
private let kPostBodyKey = "postBody"

/** @var kPendingTokenKey
    @brief The key for the "pendingToken" value in the request.
 */
private let kPendingTokenKey = "pendingToken"

/** @var kAutoCreateKey
    @brief The key for the "autoCreate" value in the request.
 */
private let kAutoCreateKey = "autoCreate"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
private let kReturnSecureTokenKey = "returnSecureToken"

/** @var kReturnIDPCredentialKey
    @brief The key for the "returnIdpCredential" value in the request.
 */
private let kReturnIDPCredentialKey = "returnIdpCredential"

/** @var kSessionIDKey
    @brief The key for the "sessionID" value in the request.
 */
private let kSessionIDKey = "sessionId"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

/** @var kUserKey
    @brief The key for the "user" value in the request. The value is a JSON object that contains the
   name of the user.
 */
private let kUserKey = "user"

/** @var kNameKey
    @brief The key for the "name" value in the request. The value is a JSON object that contains the
   first and/or last name of the user.
 */
private let kNameKey = "name"

/** @var kFirstNameKey
    @brief The key for the "firstName" value in the request.
 */
private let kFirstNameKey = "firstName"

/** @var kLastNameKey
    @brief The key for the "lastName" value in the request.
 */
private let kLastNameKey = "lastName"

/** @class FIRVerifyAssertionRequest
    @brief Represents the parameters for the verifyAssertion endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/verifyAssertion
 */
public class VerifyAssertionRequest: IdentityToolkitRequest, AuthRPCRequest {
  /** @property requestURI
      @brief The URI to which the IDP redirects the user back. It may contain federated login result
          params added by the IDP.
   */
  public var requestURI: String?

  /** @property pendingToken
      @brief The Firebase ID Token for the IDP pending to be confirmed by the user.
   */
  public var pendingToken: String?

  /** @property accessToken
      @brief The STS Access Token for the authenticated user, only needed for linking the user.
   */
  public var accessToken: String?

  /** @property returnSecureToken
      @brief Whether the response should return access token and refresh token directly.
      @remarks The default value is @c YES .
   */
  public var returnSecureToken: Bool = false

  // MARK: - Components of "postBody"

  /** @property providerID
      @brief The ID of the IDP whose credentials are being presented to the endpoint.
   */
  public let providerID: String

  /** @property providerAccessToken
      @brief An access token from the IDP.
   */
  public var providerAccessToken: String?

  /** @property providerIDToken
      @brief An ID Token from the IDP.
   */
  public var providerIDToken: String?

  /** @property providerRawNonce
      @brief An raw nonce from the IDP.
   */
  public var providerRawNonce: String?

  /** @property returnIDPCredential
      @brief Whether the response should return the IDP credential directly.
   */
  public var returnIDPCredential: Bool = false

  /** @property providerOAuthTokenSecret
      @brief A session ID used to map this request to a headful-lite flow.
   */
  public var sessionID: String?

  /** @property providerOAuthTokenSecret
      @brief An OAuth client secret from the IDP.
   */
  public var providerOAuthTokenSecret: String?

  /** @property inputEmail
      @brief The originally entered email in the UI.
   */
  public var inputEmail: String?

  /** @property autoCreate
      @brief A flag that indicates whether or not the user should be automatically created.
   */
  public var autoCreate: Bool = false

  /** @property fullName
      @brief A full name from the IdP.
   */
  public var fullName: PersonNameComponents?

  /** @var response
      @brief The corresponding response for this request
   */
  public var response: VerifyAssertionResponse = VerifyAssertionResponse()

  public init(providerID: String, requestConfiguration: AuthRequestConfiguration) {
    self.providerID = providerID
    returnSecureToken = true
    autoCreate = true
    returnIDPCredential = true

    super.init(endpoint: kVerifyAssertionEndpoint, requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var components = URLComponents()
    var queryItems: [URLQueryItem] = [URLQueryItem(name: kProviderIDKey, value: providerID)]
    if let providerIDToken = providerIDToken {
      queryItems.append(URLQueryItem(name: kProviderIDTokenKey, value: providerIDToken))
    }
    if let providerRawNonce = providerRawNonce {
      queryItems.append(URLQueryItem(name: kProviderNonceKey, value: providerRawNonce))
    }
    if let providerAccessToken = providerAccessToken {
      queryItems
        .append(URLQueryItem(name: kProviderAccessTokenKey, value: providerAccessToken))
    }
    guard providerIDToken != nil || providerAccessToken != nil || pendingToken != nil ||
      requestURI != nil else {
      fatalError("One of IDToken, accessToken, pendingToken, or requestURI must be supplied.")
    }
    if let providerOAuthTokenSecret = providerOAuthTokenSecret {
      queryItems
        .append(URLQueryItem(name: kProviderOAuthTokenSecretKey,
                             value: providerOAuthTokenSecret))
    }
    if let inputEmail = inputEmail {
      queryItems.append(URLQueryItem(name: kIdentifierKey, value: inputEmail))
    }

    if fullName?.givenName != nil || fullName?.familyName != nil {
      var nameDict = [String: String]()
      if let given = fullName?.givenName {
        nameDict[kFirstNameKey] = given
      }
      if let lastName = fullName?.familyName {
        nameDict[kLastNameKey] = lastName
      }
      let userDict = [kNameKey: nameDict]
      do {
        let userJson = try JSONEncoder().encode(userDict)
        let jsonString = String(data: userJson, encoding: .utf8)
        queryItems.append(URLQueryItem(name: kUserKey, value: jsonString))
      } catch {
        fatalError("Auth Internal error: failed to serialize dictionary to json: \(error)")
      }
    }

    components.queryItems = queryItems

    var body: [String: AnyHashable] = [
      kRequestURIKey: requestURI ?? "http://localhost", // Unused by server, but required
    ]

    if let query = components.query {
      body[kPostBodyKey] = query
    }

    if let pendingToken = pendingToken {
      body[kPendingTokenKey] = pendingToken
    }

    if let accessToken = accessToken {
      body[kIDTokenKey] = accessToken
    }

    if returnSecureToken {
      body[kReturnSecureTokenKey] = true
    }

    if returnIDPCredential {
      body[kReturnIDPCredentialKey] = true
    }

    if let sessionID = sessionID {
      body[kSessionIDKey] = sessionID
    }

    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }

    body[kAutoCreateKey] = autoCreate

    return body
  }
}

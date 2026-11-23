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

/// The "verifyAssertion" endpoint.
private let kVerifyAssertionEndpoint = "verifyAssertion"

/// The key for the "providerId" value in the request.
private let kProviderIDKey = "providerId"

/// The key for the "id_token" value in the request.
private let kProviderIDTokenKey = "id_token"

/// The key for the "nonce" value in the request.
private let kProviderNonceKey = "nonce"

/// The key for the "access_token" value in the request.
private let kProviderAccessTokenKey = "access_token"

/// The key for the "oauth_token_secret" value in the request.
private let kProviderOAuthTokenSecretKey = "oauth_token_secret"

/// The key for the "identifier" value in the request.
private let kIdentifierKey = "identifier"

/// The key for the "requestUri" value in the request.
private let kRequestURIKey = "requestUri"

/// The key for the "postBody" value in the request.
private let kPostBodyKey = "postBody"

/// The key for the "pendingToken" value in the request.
private let kPendingTokenKey = "pendingToken"

/// The key for the "autoCreate" value in the request.
private let kAutoCreateKey = "autoCreate"

/// The key for the "idToken" value in the request. This is actually the STS Access Token,
/// despite its confusing (backwards compatible) parameter name.
private let kIDTokenKey = "idToken"

/// The key for the "returnSecureToken" value in the request.
private let kReturnSecureTokenKey = "returnSecureToken"

/// The key for the "returnIdpCredential" value in the request.
private let kReturnIDPCredentialKey = "returnIdpCredential"

/// The key for the "sessionID" value in the request.
private let kSessionIDKey = "sessionId"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

/// The key for the "user" value in the request. The value is a JSON object that contains the
/// name of the user.
private let kUserKey = "user"

/// The key for the "name" value in the request. The value is a JSON object that contains the
/// first and/or last name of the user.
private let kNameKey = "name"

/// The key for the "firstName" value in the request.
private let kFirstNameKey = "firstName"

/// The key for the "lastName" value in the request.
private let kLastNameKey = "lastName"

/// Represents the parameters for the verifyAssertion endpoint.
/// See https://developers.google.com/identity/toolkit/web/reference/relyingparty/verifyAssertion
class VerifyAssertionRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = VerifyAssertionResponse

  /// The URI to which the IDP redirects the user back. It may contain federated login result
  ///    params added by the IDP.
  var requestURI: String?

  /// The Firebase ID Token for the IDP pending to be confirmed by the user.
  var pendingToken: String?

  /// The STS Access Token for the authenticated user, only needed for linking the user.
  var accessToken: String?

  /// Whether the response should return access token and refresh token directly.
  /// The default value is `true` .

  var returnSecureToken: Bool = true

  // MARK: - Components of "postBody"

  /// The ID of the IDP whose credentials are being presented to the endpoint.
  let providerID: String

  /// An access token from the IDP.
  var providerAccessToken: String?

  /// An ID Token from the IDP.
  var providerIDToken: String?

  /// An raw nonce from the IDP.
  var providerRawNonce: String?

  /// Whether the response should return the IDP credential directly.
  var returnIDPCredential: Bool = true

  /// A session ID used to map this request to a headful-lite flow.
  var sessionID: String?

  /// An OAuth client secret from the IDP.
  var providerOAuthTokenSecret: String?

  /// The originally entered email in the UI.
  var inputEmail: String?

  /// A flag that indicates whether or not the user should be automatically created.
  var autoCreate: Bool = true

  /// A full name from the IdP.
  var fullName: PersonNameComponents?

  init(providerID: String, requestConfiguration: AuthRequestConfiguration) {
    self.providerID = providerID
    super.init(endpoint: kVerifyAssertionEndpoint, requestConfiguration: requestConfiguration)
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    guard providerIDToken != nil || providerAccessToken != nil || pendingToken != nil ||
      requestURI != nil else {
      fatalError("One of IDToken, accessToken, pendingToken, or requestURI must be supplied.")
    }
    var components = URLComponents()
    components.queryItems = postBodyQueryItems

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

  /// The parameters sent in the `postBody` value, in order.
  private var postBodyQueryItems: [URLQueryItem] {
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let userJson = try encoder.encode(userDict)
        let jsonString = String(data: userJson, encoding: .utf8)
        queryItems.append(URLQueryItem(name: kUserKey, value: jsonString))
      } catch {
        fatalError("Auth Internal error: failed to serialize dictionary to json: \(error)")
      }
    }
    return queryItems
  }

  // MARK: - Diagnostics

  // These messages name the `postBody` parameters but never include their values, which can be
  // tokens or other credentials.

  /// The names of the `postBody` parameters whose value is an empty string.
  var emptyPostBodyParameterNames: [String] {
    postBodyQueryItems.filter { $0.value?.isEmpty == true }.map(\.name)
  }

  /// A warning to log before sending the request, or `nil` if no `postBody` parameter is empty.
  var emptyPostBodyParametersWarning: String? {
    let names = emptyPostBodyParameterNames
    guard let lastName = names.last else {
      return nil
    }
    let emptyDescription: String
    switch names.count {
    case 1:
      emptyDescription = "an empty \(lastName)"
    case 2:
      emptyDescription = "empty values for \(names[0]) and \(lastName)"
    default:
      emptyDescription =
        "empty values for \(names.dropLast().joined(separator: ", ")), and \(lastName)"
    }
    return "\(requestDescription) has \(emptyDescription). If you don't have a value, omit " +
      "the parameter or pass nil instead of an empty string. The server can reject empty " +
      "values, for example with INVALID_IDP_RESPONSE."
  }

  /// A summary of a failed request to log at debug level.
  func failureSummary(for error: Error) -> String {
    let nsError = error as NSError
    let errorName = nsError.userInfo[AuthErrors.userInfoNameKey] as? String ?? nsError.domain
    let parameters = postBodyQueryItems.map { item in
      item.value?.isEmpty == true ? "\(item.name) (empty)" : item.name
    }
    return "\(requestDescription) failed with \(errorName) (\(nsError.code)). " +
      "postBody parameters sent: \(parameters.joined(separator: ", "))."
  }

  /// How the messages refer to the request. The provider ID can be empty, because the public
  /// credential APIs accept any string.
  private var requestDescription: String {
    providerID.isEmpty ? "The verifyAssertion request" :
      "The verifyAssertion request for \(providerID)"
  }
}

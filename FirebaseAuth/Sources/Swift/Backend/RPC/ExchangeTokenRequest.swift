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


/// A request to exchange a third-party OIDC token for a Firebase STS token.
///
/// This structure encapsulates the parameters required to make an API request
/// to exchange an OIDC token for a Firebase ID token. It conforms to the
/// `AuthRPCRequest` protocol, providing the necessary properties and
/// methods for the authentication backend to perform the request.
@available(iOS 13, *)
struct ExchangeTokenRequest: AuthRPCRequest {
  /// The type of the expected response.
  typealias Response = ExchangeTokenResponse

  /// The OIDC provider's Authorization code or Id Token to exchange.
  let customToken: String

  /// The ExternalUserDirectoryId corresponding to the OIDC custom Token.
  let idpConfigID: String

  /// The configuration for the request, holding API key, tenant, etc.
  let config: AuthRequestConfiguration

  var path: String {
    guard let location = config.location,
          let tenant = config.tenantId,
          let project = config.auth?.app?.options.projectID
    else {
      fatalError(
        "exchangeOidcToken requires `auth.location` & `auth.tenantID`"
      )
    }
    _ = "\(location)-identityplatform.googleapis.com"
    return "/v2alpha/projects/\(project)/locations/\(location)" +
      "/tenants/\(tenant)/idpConfigs/\(idpConfigID):exchangeOidcToken"
  }

  /// Initializes a new `ExchangeTokenRequest` instance.
  ///
  /// - Parameters:
  ///   - idpConfigID: The identifier of the OIDC provider configuration.
  ///   - idToken: The third-party OIDC token to exchange.
  ///   - config: The configuration for the request.
  init(customToken: String,
       idpConfigID: String,
       config: AuthRequestConfiguration) {
    self.idpConfigID = idpConfigID
    self.customToken = customToken
    self.config = config
  }

  /// The unencoded HTTP request body for the API.
  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    return ["custom_token": customToken]
  }

  /// Constructs the URL for the API request.
  ///
  /// - Returns: The URL for the token exchange endpoint.
  /// - FatalError: if location, tenantID, projectID or apiKey are missing.
  func requestURL() -> URL {
    guard let location = config.location,
          let tenant = config.tenantId,
          let project = config.auth?.app?.options.projectID
    else {
      fatalError(
        "exchangeOidcToken requires `auth.useIdentityPlatform`, `auth.location`, `auth.tenantID` & `projectID`"
      )
    }
    let host = "\(location)-identityplatform.googleapis.com"
    let path = "/v2/projects/$\(project)/locations/$\(location)" +
      "/tenants/$\(tenant)/idpConfigs/$\(idpConfigID):exchangeOidcToken"
    guard let url = URL(string: "https://\(host)\(path)?key=\(config.apiKey)") else {
      fatalError("Failed to create URL for exchangeOidcToken")
    }
    return url
  }

  /// Returns the request configuration.
  ///
  /// - Returns: The `AuthRequestConfiguration`.
  func requestConfiguration() -> AuthRequestConfiguration { config }
}

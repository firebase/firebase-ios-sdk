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

private let kRegionalGCIPAPIHost = "identityplatform.googleapis.com"
private let kRegionalGCIPStagingAPIHost = "staging-identityplatform.sandbox.googleapis.com"

// MARK: - ExchangeTokenRequest

/// A request to exchange a third-party OIDC ID token for a Firebase ID token.
///
/// This structure encapsulates the parameters required to call the
/// `exchangeOidcToken` endpoint on the regionalized Identity Platform backend.
/// It conforms to `AuthRPCRequest`, providing the necessary properties and
/// methods for the authentication backend to perform the request.
/// This is used for the BYO-CIAM (regionalized GCIP) flow.
@available(iOS 13, *)
struct ExchangeTokenRequest: AuthRPCRequest {
  /// The type of the expected response.
  typealias Response = ExchangeTokenResponse

  /// The customer application redirects the user to the OIDC provider,
  /// and receives this idToken for the user upon successful authentication.
  let idToken: String

  /// The ID of the Identity Provider configuration, as configured  for the tenant.
  let idpConfigID: String

  /// The auth configuration for the request, holding API key, etc.
  let config: AuthRequestConfiguration

  /// Flag for whether to use the staging backend.
  let useStaging: Bool

  /// Initializes an `ExchangeTokenRequest`.
  ///
  /// - Parameters:
  ///   - idToken: The third-party OIDC ID token from the external IdP to be exchanged.
  ///   - idpConfigID: The ID of the IdP configuration.
  ///   - config: The `AuthRequestConfiguration`.
  ///   - useStaging: Set to `true` to target the staging environment. Defaults to `false`.
  init(idToken: String,
       idpConfigID: String,
       config: AuthRequestConfiguration,
       useStaging: Bool = false) {
    self.idToken = idToken
    self.idpConfigID = idpConfigID
    self.config = config
    self.useStaging = useStaging
  }

  /// The unencoded HTTP request body for the API.
  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    return ["id_token": idToken]
  }

  /// Constructs the full URL for the `ExchangeOidcToken` API endpoint.
  ///
  /// - Important: This method will cause a `fatalError` if the `location`, `tenantId`, or
  ///              `projectID` are missing from the configuration, as they are essential for
  ///              constructing a valid regional endpoint URL.
  /// - Returns: The fully constructed `URL` for the API request.
  func requestURL() -> URL {
    guard let location = config.location,
          let tenant = config.tenantId,
          let project = config.auth?.app?.options.projectID
    else {
      fatalError(
        "Internal Error: ExchangeTokenRequest requires `location`, `tenantId`, and `projectID`."
      )
    }
    let baseHost = useStaging ? kRegionalGCIPStagingAPIHost : kRegionalGCIPAPIHost
    let host = (location == "prod-global" || location == "global") ? baseHost :
      "\(location)-\(baseHost)"

    let locationPath = (location == "prod-global") ? "global" : location

    let path = "/v2beta/projects/\(project)/locations/\(locationPath)" +
      "/tenants/\(tenant)/idpConfigs/\(idpConfigID):exchangeOidcToken"

    guard let url = URL(string: "https://\(host)\(path)?key=\(config.apiKey)") else {
      fatalError("Failed to create URL for ExchangeTokenRequest")
    }
    return url
  }

  /// Returns the request configuration.
  func requestConfiguration() -> AuthRequestConfiguration {
    return config
  }
}

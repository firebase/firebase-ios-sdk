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

/// Swap a third‑party OIDC token for a Firebase STS token.
@available(iOS 13, *)
struct ExchangeTokenRequest: AuthRPCRequest {
  typealias Response = ExchangeTokenResponse

  private let idpConfigID: String
  private let idToken: String
  private let cfg: AuthRequestConfiguration
  init(idpConfigID: String,
       idToken: String,
       cfg: AuthRequestConfiguration) {
    self.idpConfigID = idpConfigID
    self.idToken = idToken
    self.cfg = cfg
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    ["id_token": idToken]
  }

  func requestURL() -> URL {
    // Pull flags from the requestConfiguration
    guard let region = cfg.location,
          let tenant = cfg.tenantId,
          let project = cfg.auth?.app?.options.projectID
    else {
      fatalError(
        "exchangeOidcToken requires auth.useIdentityPlatform, auth.location, auth.tenantID & projectID"
      )
    }
    let host = "\(region)-identityplatform.googleapis.com"
    let path = "/v2/projects/\(project)/locations/\(region)" +
      "/tenants/\(tenant)/idpConfigs/\(idpConfigID):exchangeOidcToken"
    return URL(string: "https://\(host)\(path)?key=\(cfg.apiKey)")!
  }

  func requestConfiguration() -> AuthRequestConfiguration { cfg }
}

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

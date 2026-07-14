// Copyright 2026 Google LLC
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

extension AgentPlatform.AuthConfig {
  /// Type of auth scheme.
  public enum AuthType: Codable, Sendable, Equatable, Hashable {
    /// No Auth.
    case noAuth
    
    /// API Key Auth.
    case apiKeyAuth
    
    /// HTTP Basic Auth.
    case httpBasicAuth
    
    /// Google Service Account Auth.
    case googleServiceAccountAuth
    
    /// OAuth auth.
    case oauth
    
    /// OpenID Connect (OIDC) Auth.
    case oidcAuth
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.AuthConfig.AuthType: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .noAuth: "NO_AUTH"
    case .apiKeyAuth: "API_KEY_AUTH"
    case .httpBasicAuth: "HTTP_BASIC_AUTH"
    case .googleServiceAccountAuth: "GOOGLE_SERVICE_ACCOUNT_AUTH"
    case .oauth: "OAUTH"
    case .oidcAuth: "OIDC_AUTH"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "NO_AUTH": self = .noAuth
    case "API_KEY_AUTH": self = .apiKeyAuth
    case "HTTP_BASIC_AUTH": self = .httpBasicAuth
    case "GOOGLE_SERVICE_ACCOUNT_AUTH": self = .googleServiceAccountAuth
    case "OAUTH": self = .oauth
    case "OIDC_AUTH": self = .oidcAuth
    default: self = .unrecognized(rawValue)
    }
  }
}
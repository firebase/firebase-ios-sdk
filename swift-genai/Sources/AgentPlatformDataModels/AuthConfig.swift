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


extension AgentPlatform {
  /// Auth configuration to run the extension.
  package struct AuthConfig: Codable, Sendable, Equatable, Hashable {
    /// Config for API key auth.
    package var apiKeyConfig: AuthConfigApiKeyConfig?
    
    /// Type of auth scheme.
    package var authType: AuthType?
    
    /// Config for Google Service Account auth.
    package var googleServiceAccountConfig: AuthConfigGoogleServiceAccountConfig?
    
    /// Config for HTTP Basic auth.
    package var httpBasicAuthConfig: AuthConfigHttpBasicAuthConfig?
    
    /// Config for user oauth.
    package var oauthConfig: AuthConfigOauthConfig?
    
    /// Config for user OIDC auth.
    package var oidcConfig: AuthConfigOidcConfig?
    
    /// Creates a new `AuthConfig`.
    package init(
      apiKeyConfig: AuthConfigApiKeyConfig? = nil,
      authType: AuthType? = nil,
      googleServiceAccountConfig: AuthConfigGoogleServiceAccountConfig? = nil,
      httpBasicAuthConfig: AuthConfigHttpBasicAuthConfig? = nil,
      oauthConfig: AuthConfigOauthConfig? = nil,
      oidcConfig: AuthConfigOidcConfig? = nil
    ) {
      self.apiKeyConfig = apiKeyConfig
      self.authType = authType
      self.googleServiceAccountConfig = googleServiceAccountConfig
      self.httpBasicAuthConfig = httpBasicAuthConfig
      self.oauthConfig = oauthConfig
      self.oidcConfig = oidcConfig
    }
    enum CodingKeys: String, CodingKey {
      case apiKeyConfig = "apiKeyConfig"
      case authType = "authType"
      case googleServiceAccountConfig = "googleServiceAccountConfig"
      case httpBasicAuthConfig = "httpBasicAuthConfig"
      case oauthConfig = "oauthConfig"
      case oidcConfig = "oidcConfig"
    }
  }
}
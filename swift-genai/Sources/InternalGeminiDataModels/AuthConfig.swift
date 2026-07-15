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


extension GeminiDataModels {
  /// An internal data model for `AuthConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1AuthConfig`
  /// 
  /// Auth configuration to run the extension.
  package struct AuthConfig: Codable, Sendable, Equatable, Hashable {
    /// Config for API key auth.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Config for API key auth.
    package let apiKeyConfig: AuthConfigApiKeyConfig?
    
    /// Config for HTTP Basic auth.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Config for HTTP Basic auth.
    package let httpBasicAuthConfig: AuthConfigHttpBasicAuthConfig?
    
    /// Config for Google Service Account auth.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Config for Google Service Account auth.
    package let googleServiceAccountConfig: AuthConfigGoogleServiceAccountConfig?
    
    /// Config for user oauth.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Config for user oauth.
    package let oauthConfig: AuthConfigOauthConfig?
    
    /// Config for user OIDC auth.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Config for user OIDC auth.
    package let oidcConfig: AuthConfigOidcConfig?
    
    /// Type of auth scheme.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Type of auth scheme.
    package let authType: AuthType?
    

    /// Creates a new `AuthConfig`.
    ///
    /// - Parameters:
    ///   - apiKeyConfig: Config for API key auth. (Gemini Enterprise Agent Platform only). For more details, see ``apiKeyConfig``.
    ///   - httpBasicAuthConfig: Config for HTTP Basic auth. (Gemini Enterprise Agent Platform only). For more details, see ``httpBasicAuthConfig``.
    ///   - googleServiceAccountConfig: Config for Google Service Account auth. (Gemini Enterprise Agent Platform only). For more details, see ``googleServiceAccountConfig``.
    ///   - oauthConfig: Config for user oauth. (Gemini Enterprise Agent Platform only). For more details, see ``oauthConfig``.
    ///   - oidcConfig: Config for user OIDC auth. (Gemini Enterprise Agent Platform only). For more details, see ``oidcConfig``.
    ///   - authType: Type of auth scheme. (Gemini Enterprise Agent Platform only). For more details, see ``authType``.
    package init(
      apiKeyConfig: AuthConfigApiKeyConfig? = nil,
      httpBasicAuthConfig: AuthConfigHttpBasicAuthConfig? = nil,
      googleServiceAccountConfig: AuthConfigGoogleServiceAccountConfig? = nil,
      oauthConfig: AuthConfigOauthConfig? = nil,
      oidcConfig: AuthConfigOidcConfig? = nil,
      authType: AuthType? = nil
    ) {
      self.apiKeyConfig = apiKeyConfig
      self.httpBasicAuthConfig = httpBasicAuthConfig
      self.googleServiceAccountConfig = googleServiceAccountConfig
      self.oauthConfig = oauthConfig
      self.oidcConfig = oidcConfig
      self.authType = authType
    }
    enum CodingKeys: String, CodingKey {
      case apiKeyConfig = "apiKeyConfig"
      case httpBasicAuthConfig = "httpBasicAuthConfig"
      case googleServiceAccountConfig = "googleServiceAccountConfig"
      case oauthConfig = "oauthConfig"
      case oidcConfig = "oidcConfig"
      case authType = "authType"
    }
  }
}
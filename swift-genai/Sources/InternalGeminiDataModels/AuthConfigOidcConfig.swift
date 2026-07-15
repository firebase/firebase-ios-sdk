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
  /// An internal data model for `AuthConfigOidcConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1AuthConfigOidcConfig`
  /// 
  /// Config for user OIDC auth.
  package struct AuthConfigOidcConfig: Codable, Sendable, Equatable, Hashable {
    /// OpenID Connect formatted ID token for extension endpoint.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// OpenID Connect formatted ID token for extension endpoint.
    /// Only used to propagate token from
    /// [[ExecuteExtensionRequest.runtime_auth_config]] at request time.
    package let idToken: String?
    
    /// The service account used to generate an OpenID Connect
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The service account used to generate an OpenID Connect
    /// (OIDC)-compatible JWT token signed by the Google OIDC Provider
    /// (accounts.google.com) for extension endpoint
    /// (https://cloud.google.com/iam/docs/create-short-lived-credentials-direct#sa-credentials-oidc).
    /// 
    /// - The audience for the token will be set to the URL in the server url
    /// defined in the OpenApi spec.
    /// 
    /// - If the service account is provided, the service account should grant
    /// `iam.serviceAccounts.getOpenIdToken` permission to Vertex AI Extension
    /// Service Agent
    /// (https://cloud.google.com/vertex-ai/docs/general/access-control#service-agents).
    package let serviceAccount: String?
    

    /// Creates a new `AuthConfigOidcConfig`.
    ///
    /// - Parameters:
    ///   - idToken: OpenID Connect formatted ID token for extension endpoint. (Gemini Enterprise Agent Platform only). For more details, see ``idToken``.
    ///   - serviceAccount: The service account used to generate an OpenID Connect (Gemini Enterprise Agent Platform only). For more details, see ``serviceAccount``.
    package init(
      idToken: String? = nil,
      serviceAccount: String? = nil
    ) {
      self.idToken = idToken
      self.serviceAccount = serviceAccount
    }
    enum CodingKeys: String, CodingKey {
      case idToken = "idToken"
      case serviceAccount = "serviceAccount"
    }
  }
}
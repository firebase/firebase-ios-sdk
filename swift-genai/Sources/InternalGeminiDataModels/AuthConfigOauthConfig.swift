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
  /// An internal data model for `AuthConfigOauthConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1AuthConfigOauthConfig`
  /// 
  /// Config for user oauth.
  package struct AuthConfigOauthConfig: Codable, Sendable, Equatable, Hashable {
    /// Access token for extension endpoint.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Access token for extension endpoint.
    /// Only used to propagate token from
    /// [[ExecuteExtensionRequest.runtime_auth_config]] at request time.
    package let accessToken: String?
    
    /// The service account used to generate access tokens for executing the
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The service account used to generate access tokens for executing the
    /// Extension.
    /// 
    /// - If the service account is specified,
    /// the `iam.serviceAccounts.getAccessToken` permission should be granted
    /// to Vertex AI Extension Service Agent
    /// (https://cloud.google.com/vertex-ai/docs/general/access-control#service-agents)
    /// on the provided service account.
    package let serviceAccount: String?
    

    /// Creates a new `AuthConfigOauthConfig`.
    ///
    /// - Parameters:
    ///   - accessToken: Access token for extension endpoint. (Gemini Enterprise Agent Platform only). For more details, see ``accessToken``.
    ///   - serviceAccount: The service account used to generate access tokens for executing the (Gemini Enterprise Agent Platform only). For more details, see ``serviceAccount``.
    package init(
      accessToken: String? = nil,
      serviceAccount: String? = nil
    ) {
      self.accessToken = accessToken
      self.serviceAccount = serviceAccount
    }
    enum CodingKeys: String, CodingKey {
      case accessToken = "accessToken"
      case serviceAccount = "serviceAccount"
    }
  }
}
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
  /// An internal data model for `AuthConfigHttpBasicAuthConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1AuthConfigHttpBasicAuthConfig`
  /// 
  /// Config for HTTP Basic Authentication.
  package struct AuthConfigHttpBasicAuthConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. The name of the SecretManager secret version resource storing the base64
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The name of the SecretManager secret version resource storing the base64
    /// encoded credentials.
    /// Format: `projects/{project}/secrets/{secrete}/versions/{version}`
    /// 
    /// - If specified, the `secretmanager.versions.access` permission should be
    /// granted to Vertex AI Extension Service Agent
    /// (https://cloud.google.com/vertex-ai/docs/general/access-control#service-agents)
    /// on the specified resource.
    package let credentialSecret: String
    

    /// Creates a new `AuthConfigHttpBasicAuthConfig`.
    ///
    /// - Parameters:
    ///   - credentialSecret: Required. The name of the SecretManager secret version resource storing the base64 (Gemini Enterprise Agent Platform only). For more details, see ``credentialSecret``.
    package init(
      credentialSecret: String
    ) {
      self.credentialSecret = credentialSecret
    }
    enum CodingKeys: String, CodingKey {
      case credentialSecret = "credentialSecret"
    }
  }
}
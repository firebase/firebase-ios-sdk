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
  /// An internal data model for `ApiAuthApiKeyConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ApiAuthApiKeyConfig`
  /// 
  /// The API secret.
  package struct ApiAuthApiKeyConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. The SecretManager secret version resource name storing API key.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The SecretManager secret version resource name storing API key.
    /// e.g. projects/{project}/secrets/{secret}/versions/{version}
    package let apiKeySecretVersion: String
    
    /// The API key string.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The API key string.
    /// 
    /// Either this or `api_key_secret_version` must be set.
    package let apiKeyString: String?
    

    /// Creates a new `ApiAuthApiKeyConfig`.
    ///
    /// - Parameters:
    ///   - apiKeySecretVersion: Required. The SecretManager secret version resource name storing API key. (Gemini Enterprise Agent Platform only). For more details, see ``apiKeySecretVersion``.
    ///   - apiKeyString: The API key string. (Gemini Enterprise Agent Platform only). For more details, see ``apiKeyString``.
    package init(
      apiKeySecretVersion: String,
      apiKeyString: String? = nil
    ) {
      self.apiKeySecretVersion = apiKeySecretVersion
      self.apiKeyString = apiKeyString
    }
    enum CodingKeys: String, CodingKey {
      case apiKeySecretVersion = "apiKeySecretVersion"
      case apiKeyString = "apiKeyString"
    }
  }
}
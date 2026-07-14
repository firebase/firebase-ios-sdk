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
  /// The API secret.
  public struct ApiAuthApiKeyConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. The SecretManager secret version resource name storing API key. e.g. projects/{project}/secrets/{secret}/versions/{version}
    public var apiKeySecretVersion: String?
    
    /// The API key string. Either this or `api_key_secret_version` must be set.
    public var apiKeyString: String?
    
    /// Creates a new `ApiAuthApiKeyConfig`.
    public init(
      apiKeySecretVersion: String? = nil,
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
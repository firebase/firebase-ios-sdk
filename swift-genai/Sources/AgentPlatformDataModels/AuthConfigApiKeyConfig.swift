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
  /// Config for authentication with API key.
  package struct AuthConfigApiKeyConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The name of the SecretManager secret version resource storing the API key. Format: `projects/{project}/secrets/{secrete}/versions/{version}` - If both `api_key_secret` and `api_key_string` are specified, this field takes precedence over `api_key_string`. - If specified, the `secretmanager.versions.access` permission should be granted to Vertex AI Extension Service Agent (https://cloud.google.com/vertex-ai/docs/general/access-control#service-agents) on the specified resource.
    package var apiKeySecret: String?
    
    /// Optional. The API key to be used in the request directly.
    package var apiKeyString: String?
    
    /// Optional. The location of the API key.
    package var httpElementLocation: HttpElementLocation?
    
    /// Optional. The parameter name of the API key. E.g. If the API request is "https://example.com/act?api_key=", "api_key" would be the parameter name.
    package var name: String?
    
    /// Creates a new `AuthConfigApiKeyConfig`.
    package init(
      apiKeySecret: String? = nil,
      apiKeyString: String? = nil,
      httpElementLocation: HttpElementLocation? = nil,
      name: String? = nil
    ) {
      self.apiKeySecret = apiKeySecret
      self.apiKeyString = apiKeyString
      self.httpElementLocation = httpElementLocation
      self.name = name
    }
    enum CodingKeys: String, CodingKey {
      case apiKeySecret = "apiKeySecret"
      case apiKeyString = "apiKeyString"
      case httpElementLocation = "httpElementLocation"
      case name = "name"
    }
  }
}
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
  /// Retrieve from data source powered by external API for grounding. The external API is not owned by Google, but need to follow the pre-defined API spec.
  public struct ExternalApi: Codable, Sendable, Equatable, Hashable {
    /// The authentication config to access the API. Deprecated. Please use auth_config instead.
    @available(*, deprecated)
    public var apiAuth: ApiAuth?
    
    /// The API spec that the external API implements.
    public var apiSpec: ApiSpec?
    
    /// The authentication config to access the API.
    public var authConfig: AuthConfig?
    
    /// Parameters for the elastic search API.
    public var elasticSearchParams: ExternalApiElasticSearchParams?
    
    /// The endpoint of the external API. The system will call the API at this endpoint to retrieve the data for grounding. Example: https://acme.com:443/search
    public var endpoint: String?
    
    /// Parameters for the simple search API.
    public var simpleSearchParams: ExternalApiSimpleSearchParams?
    
    /// Creates a new `ExternalApi`.
    public init(
      apiAuth: ApiAuth? = nil,
      apiSpec: ApiSpec? = nil,
      authConfig: AuthConfig? = nil,
      elasticSearchParams: ExternalApiElasticSearchParams? = nil,
      endpoint: String? = nil,
      simpleSearchParams: ExternalApiSimpleSearchParams? = nil
    ) {
      self.apiAuth = apiAuth
      self.apiSpec = apiSpec
      self.authConfig = authConfig
      self.elasticSearchParams = elasticSearchParams
      self.endpoint = endpoint
      self.simpleSearchParams = simpleSearchParams
    }
    enum CodingKeys: String, CodingKey {
      case apiAuth = "apiAuth"
      case apiSpec = "apiSpec"
      case authConfig = "authConfig"
      case elasticSearchParams = "elasticSearchParams"
      case endpoint = "endpoint"
      case simpleSearchParams = "simpleSearchParams"
    }
  }
}
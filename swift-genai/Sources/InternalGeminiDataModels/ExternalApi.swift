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
  /// An internal data model for `ExternalApi`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ExternalApi`
  /// 
  /// Retrieve from data source powered by external API for grounding.
  /// The external API is not owned by Google, but need to follow the
  /// pre-defined API spec.
  package struct ExternalApi: Codable, Sendable, Equatable, Hashable {
    /// Parameters for the simple search API.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Parameters for the simple search API.
    package let simpleSearchParams: ExternalApiSimpleSearchParams?
    
    /// Parameters for the elastic search API.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Parameters for the elastic search API.
    package let elasticSearchParams: ExternalApiElasticSearchParams?
    
    /// The API spec that the external API implements.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The API spec that the external API implements.
    package let apiSpec: ApiSpec?
    
    /// The endpoint of the external API. The system will call the API at this
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The endpoint of the external API. The system will call the API at this
    /// endpoint to retrieve the data for grounding.
    /// Example: https://acme.com:443/search
    package let endpoint: String?
    
    /// The authentication config to access the API.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The authentication config to access the API.
    /// Deprecated. Please use auth_config instead.
    @available(*, deprecated)
    package let apiAuth: ApiAuth?
    
    /// The authentication config to access the API.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The authentication config to access the API.
    package let authConfig: AuthConfig?
    

    /// Creates a new `ExternalApi`.
    ///
    /// - Parameters:
    ///   - simpleSearchParams: Parameters for the simple search API. (Gemini Enterprise Agent Platform only). For more details, see ``simpleSearchParams``.
    ///   - elasticSearchParams: Parameters for the elastic search API. (Gemini Enterprise Agent Platform only). For more details, see ``elasticSearchParams``.
    ///   - apiSpec: The API spec that the external API implements. (Gemini Enterprise Agent Platform only). For more details, see ``apiSpec``.
    ///   - endpoint: The endpoint of the external API. The system will call the API at this (Gemini Enterprise Agent Platform only). For more details, see ``endpoint``.
    ///   - apiAuth: The authentication config to access the API. (Gemini Enterprise Agent Platform only). For more details, see ``apiAuth``.
    ///   - authConfig: The authentication config to access the API. (Gemini Enterprise Agent Platform only). For more details, see ``authConfig``.
    package init(
      simpleSearchParams: ExternalApiSimpleSearchParams? = nil,
      elasticSearchParams: ExternalApiElasticSearchParams? = nil,
      apiSpec: ApiSpec? = nil,
      endpoint: String? = nil,
      apiAuth: ApiAuth? = nil,
      authConfig: AuthConfig? = nil
    ) {
      self.simpleSearchParams = simpleSearchParams
      self.elasticSearchParams = elasticSearchParams
      self.apiSpec = apiSpec
      self.endpoint = endpoint
      self.apiAuth = apiAuth
      self.authConfig = authConfig
    }
    enum CodingKeys: String, CodingKey {
      case simpleSearchParams = "simpleSearchParams"
      case elasticSearchParams = "elasticSearchParams"
      case apiSpec = "apiSpec"
      case endpoint = "endpoint"
      case apiAuth = "apiAuth"
      case authConfig = "authConfig"
    }
  }
}
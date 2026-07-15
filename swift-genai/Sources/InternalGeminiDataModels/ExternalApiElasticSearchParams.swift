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
  /// An internal data model for `ExternalApiElasticSearchParams`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ExternalApiElasticSearchParams`
  /// 
  /// The search parameters to use for the ELASTIC_SEARCH spec.
  package struct ExternalApiElasticSearchParams: Codable, Sendable, Equatable, Hashable {
    /// The ElasticSearch index to use.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The ElasticSearch index to use.
    package let index: String?
    
    /// The ElasticSearch search template to use.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The ElasticSearch search template to use.
    package let searchTemplate: String?
    
    /// Optional. Number of hits (chunks) to request.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Number of hits (chunks) to request.
    /// 
    /// When specified, it is passed to Elasticsearch as the `num_hits` param.
    package let numHits: Int?
    

    /// Creates a new `ExternalApiElasticSearchParams`.
    ///
    /// - Parameters:
    ///   - index: The ElasticSearch index to use. (Gemini Enterprise Agent Platform only). For more details, see ``index``.
    ///   - searchTemplate: The ElasticSearch search template to use. (Gemini Enterprise Agent Platform only). For more details, see ``searchTemplate``.
    ///   - numHits: Optional. Number of hits (chunks) to request. (Gemini Enterprise Agent Platform only). For more details, see ``numHits``.
    package init(
      index: String? = nil,
      searchTemplate: String? = nil,
      numHits: Int? = nil
    ) {
      self.index = index
      self.searchTemplate = searchTemplate
      self.numHits = numHits
    }
    enum CodingKeys: String, CodingKey {
      case index = "index"
      case searchTemplate = "searchTemplate"
      case numHits = "numHits"
    }
  }
}
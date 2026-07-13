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
  /// The search parameters to use for the ELASTIC_SEARCH spec.
  package struct ExternalApiElasticSearchParams: Codable, Sendable, Equatable, Hashable {
    /// The ElasticSearch index to use.
    package var index: String?
    
    /// Optional. Number of hits (chunks) to request. When specified, it is passed to Elasticsearch as the `num_hits` param.
    package var numHits: Int?
    
    /// The ElasticSearch search template to use.
    package var searchTemplate: String?
    
    /// Creates a new `ExternalApiElasticSearchParams`.
    package init(
      index: String? = nil,
      numHits: Int? = nil,
      searchTemplate: String? = nil
    ) {
      self.index = index
      self.numHits = numHits
      self.searchTemplate = searchTemplate
    }
    enum CodingKeys: String, CodingKey {
      case index = "index"
      case numHits = "numHits"
      case searchTemplate = "searchTemplate"
    }
  }
}
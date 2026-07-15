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
  /// An internal data model for `VertexAISearch`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1VertexAISearch`
  /// 
  /// Retrieve from Vertex AI Search datastore or engine for grounding.
  /// datastore and engine are mutually exclusive.
  /// See https://cloud.google.com/products/agent-builder
  package struct VertexAISearch: Codable, Sendable, Equatable, Hashable {
    /// Optional. Fully-qualified Vertex AI Search data store resource ID.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Fully-qualified Vertex AI Search data store resource ID.
    /// Format:
    /// `projects/{project}/locations/{location}/collections/{collection}/dataStores/{dataStore}`
    package let datastore: String?
    
    /// Optional. Fully-qualified Vertex AI Search engine resource ID.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Fully-qualified Vertex AI Search engine resource ID.
    /// Format:
    /// `projects/{project}/locations/{location}/collections/{collection}/engines/{engine}`
    package let engine: String?
    
    /// Optional. Number of search results to return per query.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Number of search results to return per query.
    /// The default value is 10.
    /// The maximumm allowed value is 10.
    package let maxResults: Int?
    
    /// Optional. Filter strings to be passed to the search API.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Filter strings to be passed to the search API.
    package let filter: String?
    
    /// Specifications that define the specific DataStores to be searched, along
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Specifications that define the specific DataStores to be searched, along
    /// with configurations for those data stores. This is only considered for
    /// Engines with multiple data stores.
    /// It should only be set if engine is used.
    package let dataStoreSpecs: [VertexAISearchDataStoreSpec]?
    

    /// Creates a new `VertexAISearch`.
    ///
    /// - Parameters:
    ///   - datastore: Optional. Fully-qualified Vertex AI Search data store resource ID. (Gemini Enterprise Agent Platform only). For more details, see ``datastore``.
    ///   - engine: Optional. Fully-qualified Vertex AI Search engine resource ID. (Gemini Enterprise Agent Platform only). For more details, see ``engine``.
    ///   - maxResults: Optional. Number of search results to return per query. (Gemini Enterprise Agent Platform only). For more details, see ``maxResults``.
    ///   - filter: Optional. Filter strings to be passed to the search API. (Gemini Enterprise Agent Platform only). For more details, see ``filter``.
    ///   - dataStoreSpecs: Specifications that define the specific DataStores to be searched, along (Gemini Enterprise Agent Platform only). For more details, see ``dataStoreSpecs``.
    package init(
      datastore: String? = nil,
      engine: String? = nil,
      maxResults: Int? = nil,
      filter: String? = nil,
      dataStoreSpecs: [VertexAISearchDataStoreSpec]? = nil
    ) {
      self.datastore = datastore
      self.engine = engine
      self.maxResults = maxResults
      self.filter = filter
      self.dataStoreSpecs = dataStoreSpecs
    }
    enum CodingKeys: String, CodingKey {
      case datastore = "datastore"
      case engine = "engine"
      case maxResults = "maxResults"
      case filter = "filter"
      case dataStoreSpecs = "dataStoreSpecs"
    }
  }
}
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
  /// Retrieve from Vertex AI Search datastore or engine for grounding. datastore and engine are mutually exclusive. See https://cloud.google.com/products/agent-builder
  public struct VertexAISearch: Codable, Sendable, Equatable, Hashable {
    /// Specifications that define the specific DataStores to be searched, along with configurations for those data stores. This is only considered for Engines with multiple data stores. It should only be set if engine is used.
    public var dataStoreSpecs: [VertexAISearchDataStoreSpec]?
    
    /// Optional. Fully-qualified Vertex AI Search data store resource ID. Format: `projects/{project}/locations/{location}/collections/{collection}/dataStores/{dataStore}`
    public var datastore: String?
    
    /// Optional. Fully-qualified Vertex AI Search engine resource ID. Format: `projects/{project}/locations/{location}/collections/{collection}/engines/{engine}`
    public var engine: String?
    
    /// Optional. Filter strings to be passed to the search API.
    public var filter: String?
    
    /// Optional. Number of search results to return per query. The default value is 10. The maximumm allowed value is 10.
    public var maxResults: Int?
    
    /// Creates a new `VertexAISearch`.
    public init(
      dataStoreSpecs: [VertexAISearchDataStoreSpec]? = nil,
      datastore: String? = nil,
      engine: String? = nil,
      filter: String? = nil,
      maxResults: Int? = nil
    ) {
      self.dataStoreSpecs = dataStoreSpecs
      self.datastore = datastore
      self.engine = engine
      self.filter = filter
      self.maxResults = maxResults
    }
    enum CodingKeys: String, CodingKey {
      case dataStoreSpecs = "dataStoreSpecs"
      case datastore = "datastore"
      case engine = "engine"
      case filter = "filter"
      case maxResults = "maxResults"
    }
  }
}
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
  /// An internal data model for `VertexAISearchDataStoreSpec`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1VertexAISearchDataStoreSpec`
  /// 
  /// Define data stores within engine to filter on in a search call and
  /// configurations for those data stores. For more information, see
  /// https://cloud.google.com/generative-ai-app-builder/docs/reference/rpc/google.cloud.discoveryengine.v1#datastorespec
  package struct VertexAISearchDataStoreSpec: Codable, Sendable, Equatable, Hashable {
    /// Full resource name of DataStore, such as
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Full resource name of DataStore, such as
    /// Format:
    /// `projects/{project}/locations/{location}/collections/{collection}/dataStores/{dataStore}`
    package let dataStore: String?
    
    /// Optional. Filter specification to filter documents in the data store specified by
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Filter specification to filter documents in the data store specified by
    /// data_store field. For more information on filtering, see
    /// [Filtering](https://cloud.google.com/generative-ai-app-builder/docs/filter-search-metadata)
    package let filter: String?
    

    /// Creates a new `VertexAISearchDataStoreSpec`.
    ///
    /// - Parameters:
    ///   - dataStore: Full resource name of DataStore, such as (Gemini Enterprise Agent Platform only). For more details, see ``dataStore``.
    ///   - filter: Optional. Filter specification to filter documents in the data store specified by (Gemini Enterprise Agent Platform only). For more details, see ``filter``.
    package init(
      dataStore: String? = nil,
      filter: String? = nil
    ) {
      self.dataStore = dataStore
      self.filter = filter
    }
    enum CodingKeys: String, CodingKey {
      case dataStore = "dataStore"
      case filter = "filter"
    }
  }
}
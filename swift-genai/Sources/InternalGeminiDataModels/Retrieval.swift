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
  /// An internal data model for `Retrieval`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Retrieval`
  /// 
  /// Defines a retrieval tool that model can call to access external knowledge.
  package struct Retrieval: Codable, Sendable, Equatable, Hashable {
    /// Set to use data source powered by Vertex AI Search.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Set to use data source powered by Vertex AI Search.
    package let vertexAiSearch: VertexAISearch?
    
    /// Set to use data source powered by Vertex RAG store.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Set to use data source powered by Vertex RAG store.
    /// User data is uploaded via the VertexRagDataService.
    package let vertexRagStore: VertexRagStore?
    
    /// Use data source powered by external API for grounding.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Use data source powered by external API for grounding.
    package let externalApi: ExternalApi?
    
    /// Optional. Deprecated. This option is no longer supported.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Deprecated. This option is no longer supported.
    @available(*, deprecated)
    package let disableAttribution: Bool?
    

    /// Creates a new `Retrieval`.
    ///
    /// - Parameters:
    ///   - vertexAiSearch: Set to use data source powered by Vertex AI Search. (Gemini Enterprise Agent Platform only). For more details, see ``vertexAiSearch``.
    ///   - vertexRagStore: Set to use data source powered by Vertex RAG store. (Gemini Enterprise Agent Platform only). For more details, see ``vertexRagStore``.
    ///   - externalApi: Use data source powered by external API for grounding. (Gemini Enterprise Agent Platform only). For more details, see ``externalApi``.
    ///   - disableAttribution: Optional. Deprecated. This option is no longer supported. (Gemini Enterprise Agent Platform only). For more details, see ``disableAttribution``.
    package init(
      vertexAiSearch: VertexAISearch? = nil,
      vertexRagStore: VertexRagStore? = nil,
      externalApi: ExternalApi? = nil,
      disableAttribution: Bool? = nil
    ) {
      self.vertexAiSearch = vertexAiSearch
      self.vertexRagStore = vertexRagStore
      self.externalApi = externalApi
      self.disableAttribution = disableAttribution
    }
    enum CodingKeys: String, CodingKey {
      case vertexAiSearch = "vertexAiSearch"
      case vertexRagStore = "vertexRagStore"
      case externalApi = "externalApi"
      case disableAttribution = "disableAttribution"
    }
  }
}
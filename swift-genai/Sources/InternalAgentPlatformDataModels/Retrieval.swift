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
  /// Defines a retrieval tool that model can call to access external knowledge.
  public struct Retrieval: Codable, Sendable, Equatable, Hashable {
    /// Optional. Deprecated. This option is no longer supported.
    @available(*, deprecated)
    public var disableAttribution: Bool?
    
    /// Use data source powered by external API for grounding.
    public var externalApi: ExternalApi?
    
    /// Set to use data source powered by Vertex AI Search.
    public var vertexAiSearch: VertexAISearch?
    
    /// Set to use data source powered by Vertex RAG store. User data is uploaded via the VertexRagDataService.
    public var vertexRagStore: VertexRagStore?
    
    /// Creates a new `Retrieval`.
    public init(
      disableAttribution: Bool? = nil,
      externalApi: ExternalApi? = nil,
      vertexAiSearch: VertexAISearch? = nil,
      vertexRagStore: VertexRagStore? = nil
    ) {
      self.disableAttribution = disableAttribution
      self.externalApi = externalApi
      self.vertexAiSearch = vertexAiSearch
      self.vertexRagStore = vertexRagStore
    }
    enum CodingKeys: String, CodingKey {
      case disableAttribution = "disableAttribution"
      case externalApi = "externalApi"
      case vertexAiSearch = "vertexAiSearch"
      case vertexRagStore = "vertexRagStore"
    }
  }
}
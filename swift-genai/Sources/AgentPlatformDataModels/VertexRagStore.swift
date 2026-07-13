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
  /// Retrieve from Vertex RAG Store for grounding.
  package struct VertexRagStore: Codable, Sendable, Equatable, Hashable {
    /// Optional. Deprecated. Please use rag_resources instead.
    @available(*, deprecated)
    package var ragCorpora: [String]?
    
    /// Optional. The representation of the rag source. It can be used to specify corpus only or ragfiles. Currently only support one corpus or multiple files from one corpus. In the future we may open up multiple corpora support.
    package var ragResources: [VertexRagStoreRagResource]?
    
    /// Optional. The retrieval config for the Rag query.
    package var ragRetrievalConfig: RagRetrievalConfig?
    
    /// Optional. Number of top k results to return from the selected corpora.
    @available(*, deprecated)
    package var similarityTopK: Int?
    
    /// Optional. Currently only supported for Gemini Multimodal Live API. In Gemini Multimodal Live API, if `store_context` bool is specified, Gemini will leverage it to automatically memorize the interactions between the client and Gemini, and retrieve context when needed to augment the response generation for users' ongoing and future interactions.
    package var storeContext: Bool?
    
    /// Optional. Only return results with vector distance smaller than the threshold.
    @available(*, deprecated)
    package var vectorDistanceThreshold: Double?
    
    /// Creates a new `VertexRagStore`.
    package init(
      ragCorpora: [String]? = nil,
      ragResources: [VertexRagStoreRagResource]? = nil,
      ragRetrievalConfig: RagRetrievalConfig? = nil,
      similarityTopK: Int? = nil,
      storeContext: Bool? = nil,
      vectorDistanceThreshold: Double? = nil
    ) {
      self.ragCorpora = ragCorpora
      self.ragResources = ragResources
      self.ragRetrievalConfig = ragRetrievalConfig
      self.similarityTopK = similarityTopK
      self.storeContext = storeContext
      self.vectorDistanceThreshold = vectorDistanceThreshold
    }
    enum CodingKeys: String, CodingKey {
      case ragCorpora = "ragCorpora"
      case ragResources = "ragResources"
      case ragRetrievalConfig = "ragRetrievalConfig"
      case similarityTopK = "similarityTopK"
      case storeContext = "storeContext"
      case vectorDistanceThreshold = "vectorDistanceThreshold"
    }
  }
}
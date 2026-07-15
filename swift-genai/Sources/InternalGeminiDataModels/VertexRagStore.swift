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
  /// An internal data model for `VertexRagStore`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1VertexRagStore`
  /// 
  /// Retrieve from Vertex RAG Store for grounding.
  package struct VertexRagStore: Codable, Sendable, Equatable, Hashable {
    /// Optional. Deprecated. Please use rag_resources instead.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Deprecated. Please use rag_resources instead.
    @available(*, deprecated)
    package let ragCorpora: [String]?
    
    /// Optional. The representation of the rag source. It can be used to specify corpus
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The representation of the rag source. It can be used to specify corpus
    /// only or ragfiles. Currently only support one corpus or multiple files
    /// from one corpus. In the future we may open up multiple corpora support.
    package let ragResources: [VertexRagStoreRagResource]?
    
    /// Optional. Number of top k results to return from the selected corpora.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Number of top k results to return from the selected corpora.
    @available(*, deprecated)
    package let similarityTopK: Int?
    
    /// Optional. Only return results with vector distance smaller than the threshold.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Only return results with vector distance smaller than the threshold.
    @available(*, deprecated)
    package let vectorDistanceThreshold: Double?
    
    /// Optional. The retrieval config for the Rag query.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The retrieval config for the Rag query.
    package let ragRetrievalConfig: RagRetrievalConfig?
    
    /// Optional. Currently only supported for Gemini Multimodal Live API.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Currently only supported for Gemini Multimodal Live API.
    /// 
    /// In Gemini Multimodal Live API, if `store_context` bool is
    /// specified, Gemini will leverage it to automatically memorize the
    /// interactions between the client and Gemini, and retrieve context when
    /// needed to augment the response generation for users' ongoing and future
    /// interactions.
    package let storeContext: Bool?
    

    /// Creates a new `VertexRagStore`.
    ///
    /// - Parameters:
    ///   - ragCorpora: Optional. Deprecated. Please use rag_resources instead. (Gemini Enterprise Agent Platform only). For more details, see ``ragCorpora``.
    ///   - ragResources: Optional. The representation of the rag source. It can be used to specify corpus (Gemini Enterprise Agent Platform only). For more details, see ``ragResources``.
    ///   - similarityTopK: Optional. Number of top k results to return from the selected corpora. (Gemini Enterprise Agent Platform only). For more details, see ``similarityTopK``.
    ///   - vectorDistanceThreshold: Optional. Only return results with vector distance smaller than the threshold. (Gemini Enterprise Agent Platform only). For more details, see ``vectorDistanceThreshold``.
    ///   - ragRetrievalConfig: Optional. The retrieval config for the Rag query. (Gemini Enterprise Agent Platform only). For more details, see ``ragRetrievalConfig``.
    ///   - storeContext: Optional. Currently only supported for Gemini Multimodal Live API. (Gemini Enterprise Agent Platform only). For more details, see ``storeContext``.
    package init(
      ragCorpora: [String]? = nil,
      ragResources: [VertexRagStoreRagResource]? = nil,
      similarityTopK: Int? = nil,
      vectorDistanceThreshold: Double? = nil,
      ragRetrievalConfig: RagRetrievalConfig? = nil,
      storeContext: Bool? = nil
    ) {
      self.ragCorpora = ragCorpora
      self.ragResources = ragResources
      self.similarityTopK = similarityTopK
      self.vectorDistanceThreshold = vectorDistanceThreshold
      self.ragRetrievalConfig = ragRetrievalConfig
      self.storeContext = storeContext
    }
    enum CodingKeys: String, CodingKey {
      case ragCorpora = "ragCorpora"
      case ragResources = "ragResources"
      case similarityTopK = "similarityTopK"
      case vectorDistanceThreshold = "vectorDistanceThreshold"
      case ragRetrievalConfig = "ragRetrievalConfig"
      case storeContext = "storeContext"
    }
  }
}
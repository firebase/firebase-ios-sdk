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
  /// An internal data model for `RetrievedContextChunk`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingChunkRetrievedContext`
  /// 
  /// Chunk from context retrieved by the file search tool.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingChunkRetrievedContext`
  /// 
  /// Context retrieved from a data source to ground the model's response. This
  /// is used when a retrieval tool fetches information from a user-provided
  /// corpus or a public dataset.
  package struct RetrievedContextChunk: Codable, Sendable, Equatable, Hashable {
    /// Optional. URI reference of the semantic retrieval document.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. URI reference of the semantic retrieval document.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The URI of the retrieved data source.
    package let uri: String?
    
    /// Optional. Title of the document.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Title of the document.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The title of the retrieved data source.
    package let title: String?
    
    /// Optional. Text of the chunk.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Text of the chunk.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The content of the retrieved data source.
    package let text: String?
    
    /// Optional. Name of the `FileSearchStore` containing the document.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Name of the `FileSearchStore` containing the document.
    /// Example: `fileSearchStores/123`
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let fileSearchStore: String?
    
    /// Optional. User-provided metadata about the retrieved context.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. User-provided metadata about the retrieved context.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let customMetadata: [GroundingChunkCustomMetadata]?
    
    /// Optional. Page number of the retrieved context, if applicable.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Page number of the retrieved context, if applicable.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let pageNumber: Int?
    
    /// Optional. The media blob resource name for multimodal file search results.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The media blob resource name for multimodal file search results.
    /// Format: fileSearchStores/{file_search_store_id}/media/{blob_id}
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let mediaId: String?
    
    /// Additional context for a Retrieval-Augmented Generation (RAG) retrieval
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Additional context for a Retrieval-Augmented Generation (RAG) retrieval
    /// result. This is populated only when the RAG retrieval tool is used.
    package let ragChunk: RagChunk?
    
    /// Output only. The full resource name of the referenced Vertex AI Search
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The full resource name of the referenced Vertex AI Search
    /// document. This is used to identify the specific document that was
    /// retrieved. The format is
    /// `projects/{project}/locations/{location}/collections/{collection}/dataStores/{data_store}/branches/{branch}/documents/{document}`.
    package let documentName: String?
    

    /// Creates a new `RetrievedContextChunk`.
    ///
    /// - Parameters:
    ///   - uri: Optional. URI reference of the semantic retrieval document. (behavior varies by backend). For more details, see ``uri``.
    ///   - title: Optional. Title of the document. (behavior varies by backend). For more details, see ``title``.
    ///   - text: Optional. Text of the chunk. (behavior varies by backend). For more details, see ``text``.
    ///   - fileSearchStore: Optional. Name of the `FileSearchStore` containing the document. (Gemini Developer API only). For more details, see ``fileSearchStore``.
    ///   - customMetadata: Optional. User-provided metadata about the retrieved context. (Gemini Developer API only). For more details, see ``customMetadata``.
    ///   - pageNumber: Optional. Page number of the retrieved context, if applicable. (Gemini Developer API only). For more details, see ``pageNumber``.
    ///   - mediaId: Optional. The media blob resource name for multimodal file search results. (Gemini Developer API only). For more details, see ``mediaId``.
    ///   - ragChunk: Additional context for a Retrieval-Augmented Generation (RAG) retrieval (Gemini Enterprise Agent Platform only). For more details, see ``ragChunk``.
    ///   - documentName: Output only. The full resource name of the referenced Vertex AI Search (Gemini Enterprise Agent Platform only). For more details, see ``documentName``.
    package init(
      uri: String? = nil,
      title: String? = nil,
      text: String? = nil,
      fileSearchStore: String? = nil,
      customMetadata: [GroundingChunkCustomMetadata]? = nil,
      pageNumber: Int? = nil,
      mediaId: String? = nil,
      ragChunk: RagChunk? = nil,
      documentName: String? = nil
    ) {
      self.uri = uri
      self.title = title
      self.text = text
      self.fileSearchStore = fileSearchStore
      self.customMetadata = customMetadata
      self.pageNumber = pageNumber
      self.mediaId = mediaId
      self.ragChunk = ragChunk
      self.documentName = documentName
    }
    enum CodingKeys: String, CodingKey {
      case uri = "uri"
      case title = "title"
      case text = "text"
      case fileSearchStore = "fileSearchStore"
      case customMetadata = "customMetadata"
      case pageNumber = "pageNumber"
      case mediaId = "mediaId"
      case ragChunk = "ragChunk"
      case documentName = "documentName"
    }
  }
}
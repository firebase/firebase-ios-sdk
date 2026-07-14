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
  /// Chunk from context retrieved by the file search tool.
  /// 
  /// Variant:
  /// Context retrieved from a data source to ground the model's response. This is used when a retrieval tool fetches information from a user-provided corpus or a public dataset.
  package struct RetrievedContextChunk: Codable, Sendable, Equatable, Hashable {
    /// Optional. The media blob resource name for multimodal file search results. Format: fileSearchStores/{file_search_store_id}/media/{blob_id}
    /// 
    /// > Important: `mediaId` is only available in the Gemini Developer API.
    package let mediaId: String?
    
    /// Optional. User-provided metadata about the retrieved context.
    /// 
    /// > Important: `customMetadata` is only available in the Gemini Developer API.
    package let customMetadata: [GroundingChunkCustomMetadata]?
    
    /// Optional. Text of the chunk.
    /// 
    /// Variant:
    /// The content of the retrieved data source.
    package let text: String?
    
    /// Additional context for a Retrieval-Augmented Generation (RAG) retrieval result. This is populated only when the RAG retrieval tool is used.
    /// 
    /// > Important: `ragChunk` is only available in the Gemini Enterprise Agent Platform.
    package let ragChunk: RagChunk?
    
    /// Optional. Page number of the retrieved context, if applicable.
    /// 
    /// > Important: `pageNumber` is only available in the Gemini Developer API.
    package let pageNumber: Int?
    
    /// Optional. Name of the `FileSearchStore` containing the document. Example: `fileSearchStores/123`
    /// 
    /// > Important: `fileSearchStore` is only available in the Gemini Developer API.
    package let fileSearchStore: String?
    
    /// Optional. Title of the document.
    /// 
    /// Variant:
    /// The title of the retrieved data source.
    package let title: String?
    
    /// Optional. URI reference of the semantic retrieval document.
    /// 
    /// Variant:
    /// The URI of the retrieved data source.
    package let uri: String?
    
    /// Output only. The full resource name of the referenced Vertex AI Search document. This is used to identify the specific document that was retrieved. The format is `projects/{project}/locations/{location}/collections/{collection}/dataStores/{data_store}/branches/{branch}/documents/{document}`.
    /// 
    /// > Important: `documentName` is only available in the Gemini Enterprise Agent Platform.
    package let documentName: String?
    
    /// Creates a new `RetrievedContextChunk`.
    package init(
      mediaId: String? = nil,
      customMetadata: [GroundingChunkCustomMetadata]? = nil,
      text: String? = nil,
      ragChunk: RagChunk? = nil,
      pageNumber: Int? = nil,
      fileSearchStore: String? = nil,
      title: String? = nil,
      uri: String? = nil,
      documentName: String? = nil
    ) {
      self.mediaId = mediaId
      self.customMetadata = customMetadata
      self.text = text
      self.ragChunk = ragChunk
      self.pageNumber = pageNumber
      self.fileSearchStore = fileSearchStore
      self.title = title
      self.uri = uri
      self.documentName = documentName
    }
    enum CodingKeys: String, CodingKey {
      case mediaId = "mediaId"
      case customMetadata = "customMetadata"
      case text = "text"
      case ragChunk = "ragChunk"
      case pageNumber = "pageNumber"
      case fileSearchStore = "fileSearchStore"
      case title = "title"
      case uri = "uri"
      case documentName = "documentName"
    }
  }
}
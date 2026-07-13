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


extension GoogleAI {
  /// Chunk from context retrieved by the file search tool.
  package struct RetrievedContext: Codable, Sendable, Equatable, Hashable {
    /// Optional. User-provided metadata about the retrieved context.
    package var customMetadata: [GroundingChunkCustomMetadata]?
    
    /// Optional. Name of the `FileSearchStore` containing the document. Example: `fileSearchStores/123`
    package var fileSearchStore: String?
    
    /// Optional. The media blob resource name for multimodal file search results. Format: fileSearchStores/{file_search_store_id}/media/{blob_id}
    package var mediaId: String?
    
    /// Optional. Page number of the retrieved context, if applicable.
    package var pageNumber: Int?
    
    /// Optional. Text of the chunk.
    package var text: String?
    
    /// Optional. Title of the document.
    package var title: String?
    
    /// Optional. URI reference of the semantic retrieval document.
    package var uri: String?
    
    /// Creates a new `RetrievedContext`.
    package init(
      customMetadata: [GroundingChunkCustomMetadata]? = nil,
      fileSearchStore: String? = nil,
      mediaId: String? = nil,
      pageNumber: Int? = nil,
      text: String? = nil,
      title: String? = nil,
      uri: String? = nil
    ) {
      self.customMetadata = customMetadata
      self.fileSearchStore = fileSearchStore
      self.mediaId = mediaId
      self.pageNumber = pageNumber
      self.text = text
      self.title = title
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case customMetadata = "customMetadata"
      case fileSearchStore = "fileSearchStore"
      case mediaId = "mediaId"
      case pageNumber = "pageNumber"
      case text = "text"
      case title = "title"
      case uri = "uri"
    }
  }
}
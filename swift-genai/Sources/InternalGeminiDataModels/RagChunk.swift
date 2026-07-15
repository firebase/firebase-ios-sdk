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
  /// An internal data model for `RagChunk`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1RagChunk`
  /// 
  /// A RagChunk includes the content of a chunk of a RagFile, and associated
  /// metadata.
  package struct RagChunk: Codable, Sendable, Equatable, Hashable {
    /// The content of the chunk.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The content of the chunk.
    package let text: String?
    
    /// If populated, represents where the chunk starts and ends in the document.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// If populated, represents where the chunk starts and ends in the document.
    package let pageSpan: RagChunkPageSpan?
    
    /// The ID of the file that the chunk belongs to.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The ID of the file that the chunk belongs to.
    package let fileId: String?
    
    /// The ID of the chunk.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The ID of the chunk.
    package let chunkId: String?
    

    /// Creates a new `RagChunk`.
    ///
    /// - Parameters:
    ///   - text: The content of the chunk. (Gemini Enterprise Agent Platform only). For more details, see ``text``.
    ///   - pageSpan: If populated, represents where the chunk starts and ends in the document. (Gemini Enterprise Agent Platform only). For more details, see ``pageSpan``.
    ///   - fileId: The ID of the file that the chunk belongs to. (Gemini Enterprise Agent Platform only). For more details, see ``fileId``.
    ///   - chunkId: The ID of the chunk. (Gemini Enterprise Agent Platform only). For more details, see ``chunkId``.
    package init(
      text: String? = nil,
      pageSpan: RagChunkPageSpan? = nil,
      fileId: String? = nil,
      chunkId: String? = nil
    ) {
      self.text = text
      self.pageSpan = pageSpan
      self.fileId = fileId
      self.chunkId = chunkId
    }
    enum CodingKeys: String, CodingKey {
      case text = "text"
      case pageSpan = "pageSpan"
      case fileId = "fileId"
      case chunkId = "chunkId"
    }
  }
}
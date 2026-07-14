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
  /// A RagChunk includes the content of a chunk of a RagFile, and associated metadata.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct RagChunk: Codable, Sendable, Equatable, Hashable {
    /// The content of the chunk.
    /// 
    /// > Important: `text` is only available in the Gemini Enterprise Agent Platform.
    package let text: String?
    
    /// The ID of the file that the chunk belongs to.
    /// 
    /// > Important: `fileId` is only available in the Gemini Enterprise Agent Platform.
    package let fileId: String?
    
    /// The ID of the chunk.
    /// 
    /// > Important: `chunkId` is only available in the Gemini Enterprise Agent Platform.
    package let chunkId: String?
    
    /// If populated, represents where the chunk starts and ends in the document.
    /// 
    /// > Important: `pageSpan` is only available in the Gemini Enterprise Agent Platform.
    package let pageSpan: RagChunkPageSpan?
    
    /// Creates a new `RagChunk`.
    package init(
      text: String? = nil,
      fileId: String? = nil,
      chunkId: String? = nil,
      pageSpan: RagChunkPageSpan? = nil
    ) {
      self.text = text
      self.fileId = fileId
      self.chunkId = chunkId
      self.pageSpan = pageSpan
    }
    enum CodingKeys: String, CodingKey {
      case text = "text"
      case fileId = "fileId"
      case chunkId = "chunkId"
      case pageSpan = "pageSpan"
    }
  }
}
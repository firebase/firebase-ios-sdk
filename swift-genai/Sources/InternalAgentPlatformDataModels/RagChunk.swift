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
  /// A RagChunk includes the content of a chunk of a RagFile, and associated metadata.
  public struct RagChunk: Codable, Sendable, Equatable, Hashable {
    /// The ID of the chunk.
    public var chunkId: String?
    
    /// The ID of the file that the chunk belongs to.
    public var fileId: String?
    
    /// If populated, represents where the chunk starts and ends in the document.
    public var pageSpan: RagChunkPageSpan?
    
    /// The content of the chunk.
    public var text: String?
    
    /// Creates a new `RagChunk`.
    public init(
      chunkId: String? = nil,
      fileId: String? = nil,
      pageSpan: RagChunkPageSpan? = nil,
      text: String? = nil
    ) {
      self.chunkId = chunkId
      self.fileId = fileId
      self.pageSpan = pageSpan
      self.text = text
    }
    enum CodingKeys: String, CodingKey {
      case chunkId = "chunkId"
      case fileId = "fileId"
      case pageSpan = "pageSpan"
      case text = "text"
    }
  }
}
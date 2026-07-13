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
  /// Identifier for a `Chunk` retrieved via Semantic Retriever specified in the `GenerateAnswerRequest` using `SemanticRetrieverConfig`.
  package struct SemanticRetrieverChunk: Codable, Sendable, Equatable, Hashable {
    /// Output only. Name of the `Chunk` containing the attributed text. Example: `corpora/123/documents/abc/chunks/xyz`
    package var chunk: String?
    
    /// Output only. Name of the source matching the request's `SemanticRetrieverConfig.source`. Example: `corpora/123` or `corpora/123/documents/abc`
    package var source: String?
    
    /// Creates a new `SemanticRetrieverChunk`.
    package init(
      chunk: String? = nil,
      source: String? = nil
    ) {
      self.chunk = chunk
      self.source = source
    }
    enum CodingKeys: String, CodingKey {
      case chunk = "chunk"
      case source = "source"
    }
  }
}
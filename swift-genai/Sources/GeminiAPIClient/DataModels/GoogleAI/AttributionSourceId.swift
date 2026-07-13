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
  /// Identifier for the source contributing to this attribution.
  package struct AttributionSourceId: Codable, Sendable, Equatable, Hashable {
    /// Identifier for an inline passage.
    package var groundingPassage: GroundingPassageId?
    
    /// Identifier for a `Chunk` fetched via Semantic Retriever.
    package var semanticRetrieverChunk: SemanticRetrieverChunk?
    
    /// Creates a new `AttributionSourceId`.
    package init(
      groundingPassage: GroundingPassageId? = nil,
      semanticRetrieverChunk: SemanticRetrieverChunk? = nil
    ) {
      self.groundingPassage = groundingPassage
      self.semanticRetrieverChunk = semanticRetrieverChunk
    }
    enum CodingKeys: String, CodingKey {
      case groundingPassage = "groundingPassage"
      case semanticRetrieverChunk = "semanticRetrieverChunk"
    }
  }
}
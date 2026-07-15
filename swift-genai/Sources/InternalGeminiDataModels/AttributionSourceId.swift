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
  /// An internal data model for `AttributionSourceId`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaAttributionSourceId`
  /// 
  /// Identifier for the source contributing to this attribution.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct AttributionSourceId: Codable, Sendable, Equatable, Hashable {
    /// Identifier for an inline passage.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Identifier for an inline passage.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let groundingPassage: AttributionSourceIdGroundingPassageId?
    
    /// Identifier for a `Chunk` fetched via Semantic Retriever.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Identifier for a `Chunk` fetched via Semantic Retriever.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let semanticRetrieverChunk: AttributionSourceIdSemanticRetrieverChunk?
    

    /// Creates a new `AttributionSourceId`.
    ///
    /// - Parameters:
    ///   - groundingPassage: Identifier for an inline passage. (Gemini Developer API only). For more details, see ``groundingPassage``.
    ///   - semanticRetrieverChunk: Identifier for a `Chunk` fetched via Semantic Retriever. (Gemini Developer API only). For more details, see ``semanticRetrieverChunk``.
    package init(
      groundingPassage: AttributionSourceIdGroundingPassageId? = nil,
      semanticRetrieverChunk: AttributionSourceIdSemanticRetrieverChunk? = nil
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
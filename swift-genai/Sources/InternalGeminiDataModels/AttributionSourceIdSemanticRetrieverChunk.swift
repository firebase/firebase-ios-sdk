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
  /// An internal data model for `AttributionSourceIdSemanticRetrieverChunk`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaAttributionSourceIdSemanticRetrieverChunk`
  /// 
  /// Identifier for a `Chunk` retrieved via Semantic Retriever specified in the
  /// `GenerateAnswerRequest` using `SemanticRetrieverConfig`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct AttributionSourceIdSemanticRetrieverChunk: Codable, Sendable, Equatable, Hashable {
    /// Output only. Name of the source matching the request's
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Name of the source matching the request's
    /// `SemanticRetrieverConfig.source`. Example: `corpora/123` or
    /// `corpora/123/documents/abc`
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let source: String?
    
    /// Output only. Name of the `Chunk` containing the attributed text.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Name of the `Chunk` containing the attributed text.
    /// Example: `corpora/123/documents/abc/chunks/xyz`
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let chunk: String?
    

    /// Creates a new `AttributionSourceIdSemanticRetrieverChunk`.
    ///
    /// - Parameters:
    ///   - source: Output only. Name of the source matching the request's (Gemini Developer API only). For more details, see ``source``.
    ///   - chunk: Output only. Name of the `Chunk` containing the attributed text. (Gemini Developer API only). For more details, see ``chunk``.
    package init(
      source: String? = nil,
      chunk: String? = nil
    ) {
      self.source = source
      self.chunk = chunk
    }
    enum CodingKeys: String, CodingKey {
      case source = "source"
      case chunk = "chunk"
    }
  }
}
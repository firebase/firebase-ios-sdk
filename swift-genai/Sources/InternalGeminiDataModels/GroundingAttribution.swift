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
  /// An internal data model for `GroundingAttribution`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingAttribution`
  /// 
  /// Attribution for a source that contributed to an answer.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct GroundingAttribution: Codable, Sendable, Equatable, Hashable {
    /// Output only. Identifier for the source contributing to this attribution.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Identifier for the source contributing to this attribution.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let sourceId: AttributionSourceId?
    
    /// Grounding source content that makes up this attribution.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Grounding source content that makes up this attribution.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let content: Content?
    

    /// Creates a new `GroundingAttribution`.
    ///
    /// - Parameters:
    ///   - sourceId: Output only. Identifier for the source contributing to this attribution. (Gemini Developer API only). For more details, see ``sourceId``.
    ///   - content: Grounding source content that makes up this attribution. (Gemini Developer API only). For more details, see ``content``.
    package init(
      sourceId: AttributionSourceId? = nil,
      content: Content? = nil
    ) {
      self.sourceId = sourceId
      self.content = content
    }
    enum CodingKeys: String, CodingKey {
      case sourceId = "sourceId"
      case content = "content"
    }
  }
}
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
  /// Attribution for a source that contributed to an answer.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct GroundingAttribution: Codable, Sendable, Equatable, Hashable {
    /// Grounding source content that makes up this attribution.
    /// 
    /// > Important: `content` is only available in the Gemini Developer API.
    package let content: Content?
    
    /// Output only. Identifier for the source contributing to this attribution.
    /// 
    /// > Important: `sourceId` is only available in the Gemini Developer API.
    package let sourceId: AttributionSourceId?
    
    /// Creates a new `GroundingAttribution`.
    package init(
      content: Content? = nil,
      sourceId: AttributionSourceId? = nil
    ) {
      self.content = content
      self.sourceId = sourceId
    }
    enum CodingKeys: String, CodingKey {
      case content = "content"
      case sourceId = "sourceId"
    }
  }
}
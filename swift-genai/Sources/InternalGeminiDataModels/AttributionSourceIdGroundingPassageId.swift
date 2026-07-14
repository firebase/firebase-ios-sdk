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
  /// Identifier for a part within a `GroundingPassage`.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct AttributionSourceIdGroundingPassageId: Codable, Sendable, Equatable, Hashable {
    /// Output only. ID of the passage matching the `GenerateAnswerRequest`'s `GroundingPassage.id`.
    /// 
    /// > Important: `passageId` is only available in the Gemini Developer API.
    package let passageId: String?
    
    /// Output only. Index of the part within the `GenerateAnswerRequest`'s `GroundingPassage.content`.
    /// 
    /// > Important: `partIndex` is only available in the Gemini Developer API.
    package let partIndex: Int?
    
    /// Creates a new `AttributionSourceIdGroundingPassageId`.
    package init(
      passageId: String? = nil,
      partIndex: Int? = nil
    ) {
      self.passageId = passageId
      self.partIndex = partIndex
    }
    enum CodingKeys: String, CodingKey {
      case passageId = "passageId"
      case partIndex = "partIndex"
    }
  }
}
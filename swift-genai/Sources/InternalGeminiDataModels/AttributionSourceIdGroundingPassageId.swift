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
  /// An internal data model for `AttributionSourceIdGroundingPassageId`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaAttributionSourceIdGroundingPassageId`
  /// 
  /// Identifier for a part within a `GroundingPassage`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct AttributionSourceIdGroundingPassageId: Codable, Sendable, Equatable, Hashable {
    /// Output only. ID of the passage matching the `GenerateAnswerRequest`'s
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. ID of the passage matching the `GenerateAnswerRequest`'s
    /// `GroundingPassage.id`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let passageId: String?
    
    /// Output only. Index of the part within the `GenerateAnswerRequest`'s
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Index of the part within the `GenerateAnswerRequest`'s
    /// `GroundingPassage.content`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let partIndex: Int?
    

    /// Creates a new `AttributionSourceIdGroundingPassageId`.
    ///
    /// - Parameters:
    ///   - passageId: Output only. ID of the passage matching the `GenerateAnswerRequest`'s (Gemini Developer API only). For more details, see ``passageId``.
    ///   - partIndex: Output only. Index of the part within the `GenerateAnswerRequest`'s (Gemini Developer API only). For more details, see ``partIndex``.
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
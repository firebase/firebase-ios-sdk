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
  /// An internal data model for `PromptFeedback`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGenerateContentResponsePromptFeedback`
  /// 
  /// A set of the feedback metadata the prompt specified in
  /// `GenerateContentRequest.content`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GenerateContentResponsePromptFeedback`
  /// 
  /// Content filter results for a prompt sent in the request.
  /// Note: This is sent only in the first stream chunk and only if no
  /// candidates were generated due to content violations.
  package struct PromptFeedback: Codable, Sendable, Equatable, Hashable {
    /// Optional. If set, the prompt was blocked and no candidates are returned.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. If set, the prompt was blocked and no candidates are returned.
    /// Rephrase the prompt.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The reason why the prompt was blocked.
    package let blockReason: BlockReason?
    
    /// Ratings for safety of the prompt.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Ratings for safety of the prompt.
    /// There is at most one rating per category.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A list of safety ratings for the prompt. There is one rating per
    /// category.
    package let safetyRatings: [SafetyRating]?
    
    /// Output only. A readable message that explains the reason why the prompt was
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A readable message that explains the reason why the prompt was
    /// blocked.
    package let blockReasonMessage: String?
    

    /// Creates a new `PromptFeedback`.
    ///
    /// - Parameters:
    ///   - blockReason: Optional. If set, the prompt was blocked and no candidates are returned. (behavior varies by backend). For more details, see ``blockReason``.
    ///   - safetyRatings: Ratings for safety of the prompt. (behavior varies by backend). For more details, see ``safetyRatings``.
    ///   - blockReasonMessage: Output only. A readable message that explains the reason why the prompt was (Gemini Enterprise Agent Platform only). For more details, see ``blockReasonMessage``.
    package init(
      blockReason: BlockReason? = nil,
      safetyRatings: [SafetyRating]? = nil,
      blockReasonMessage: String? = nil
    ) {
      self.blockReason = blockReason
      self.safetyRatings = safetyRatings
      self.blockReasonMessage = blockReasonMessage
    }
    enum CodingKeys: String, CodingKey {
      case blockReason = "blockReason"
      case safetyRatings = "safetyRatings"
      case blockReasonMessage = "blockReasonMessage"
    }
  }
}
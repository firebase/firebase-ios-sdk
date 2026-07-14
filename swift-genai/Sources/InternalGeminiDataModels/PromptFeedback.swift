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
  /// A set of the feedback metadata the prompt specified in `GenerateContentRequest.content`.
  /// 
  /// Variant:
  /// Content filter results for a prompt sent in the request. Note: This is sent only in the first stream chunk and only if no candidates were generated due to content violations.
  package struct PromptFeedback: Codable, Sendable, Equatable, Hashable {
    /// Output only. A readable message that explains the reason why the prompt was blocked.
    /// 
    /// > Important: `blockReasonMessage` is only available in the Gemini Enterprise Agent Platform.
    package let blockReasonMessage: String?
    
    /// Ratings for safety of the prompt. There is at most one rating per category.
    /// 
    /// Variant:
    /// Output only. A list of safety ratings for the prompt. There is one rating per category.
    package let safetyRatings: [SafetyRating]?
    
    /// Optional. If set, the prompt was blocked and no candidates are returned. Rephrase the prompt.
    /// 
    /// Variant:
    /// Output only. The reason why the prompt was blocked.
    package let blockReason: BlockReason?
    
    /// Creates a new `PromptFeedback`.
    package init(
      blockReasonMessage: String? = nil,
      safetyRatings: [SafetyRating]? = nil,
      blockReason: BlockReason? = nil
    ) {
      self.blockReasonMessage = blockReasonMessage
      self.safetyRatings = safetyRatings
      self.blockReason = blockReason
    }
    enum CodingKeys: String, CodingKey {
      case blockReasonMessage = "blockReasonMessage"
      case safetyRatings = "safetyRatings"
      case blockReason = "blockReason"
    }
  }
}
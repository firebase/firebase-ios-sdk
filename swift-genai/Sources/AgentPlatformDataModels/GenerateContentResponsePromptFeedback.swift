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


extension AgentPlatform {
  /// Content filter results for a prompt sent in the request. Note: This is sent only in the first stream chunk and only if no candidates were generated due to content violations.
  package struct GenerateContentResponsePromptFeedback: Codable, Sendable, Equatable, Hashable {
    /// Output only. The reason why the prompt was blocked.
    package var blockReason: BlockReason?
    
    /// Output only. A readable message that explains the reason why the prompt was blocked.
    package var blockReasonMessage: String?
    
    /// Output only. A list of safety ratings for the prompt. There is one rating per category.
    package var safetyRatings: [SafetyRating]?
    
    /// Creates a new `GenerateContentResponsePromptFeedback`.
    package init(
      blockReason: BlockReason? = nil,
      blockReasonMessage: String? = nil,
      safetyRatings: [SafetyRating]? = nil
    ) {
      self.blockReason = blockReason
      self.blockReasonMessage = blockReasonMessage
      self.safetyRatings = safetyRatings
    }
    enum CodingKeys: String, CodingKey {
      case blockReason = "blockReason"
      case blockReasonMessage = "blockReasonMessage"
      case safetyRatings = "safetyRatings"
    }
  }
}
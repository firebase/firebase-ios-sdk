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
  /// A set of the feedback metadata the prompt specified in `GenerateContentRequest.content`.
  package struct PromptFeedback: Codable, Sendable, Equatable, Hashable {
    /// Optional. If set, the prompt was blocked and no candidates are returned. Rephrase the prompt.
    package var blockReason: BlockReason?
    
    /// Ratings for safety of the prompt. There is at most one rating per category.
    package var safetyRatings: [SafetyRating]?
    
    /// Creates a new `PromptFeedback`.
    package init(
      blockReason: BlockReason? = nil,
      safetyRatings: [SafetyRating]? = nil
    ) {
      self.blockReason = blockReason
      self.safetyRatings = safetyRatings
    }
    enum CodingKeys: String, CodingKey {
      case blockReason = "blockReason"
      case safetyRatings = "safetyRatings"
    }
  }
}
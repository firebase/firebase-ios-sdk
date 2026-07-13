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
  /// Safety rating for a piece of content. The safety rating contains the category of harm and the harm probability level in that category for a piece of content. Content is classified for safety across a number of harm categories and the probability of the harm classification is included here.
  package struct SafetyRating: Codable, Sendable, Equatable, Hashable {
    /// Was this content blocked because of this rating?
    package var blocked: Bool?
    
    /// Required. The category for this rating.
    package var category: Category?
    
    /// Required. The probability of harm for this content.
    package var probability: Probability?
    
    /// Creates a new `SafetyRating`.
    package init(
      blocked: Bool? = nil,
      category: Category? = nil,
      probability: Probability? = nil
    ) {
      self.blocked = blocked
      self.category = category
      self.probability = probability
    }
    enum CodingKeys: String, CodingKey {
      case blocked = "blocked"
      case category = "category"
      case probability = "probability"
    }
  }
}
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
  /// Config for thinking features.
  package struct ThinkingConfig: Codable, Sendable, Equatable, Hashable {
    /// Indicates whether to include thoughts in the response. If true, thoughts are returned only when available.
    package var includeThoughts: Bool?
    
    /// The number of thoughts tokens that the model should generate.
    package var thinkingBudget: Int?
    
    /// Optional. Controls the maximum depth of the model's internal reasoning process before it produces a response. The default value is model-dependent. Refer to the [Thinking levels guide](https://ai.google.dev/gemini-api/docs/thinking#thinking-levels) for more details. Recommended for Gemini 3 or later models. Use with earlier models results in an error.
    package var thinkingLevel: ThinkingLevel?
    
    /// Creates a new `ThinkingConfig`.
    package init(
      includeThoughts: Bool? = nil,
      thinkingBudget: Int? = nil,
      thinkingLevel: ThinkingLevel? = nil
    ) {
      self.includeThoughts = includeThoughts
      self.thinkingBudget = thinkingBudget
      self.thinkingLevel = thinkingLevel
    }
    enum CodingKeys: String, CodingKey {
      case includeThoughts = "includeThoughts"
      case thinkingBudget = "thinkingBudget"
      case thinkingLevel = "thinkingLevel"
    }
  }
}
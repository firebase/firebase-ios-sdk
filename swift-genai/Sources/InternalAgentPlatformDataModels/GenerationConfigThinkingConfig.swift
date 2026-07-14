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
  /// Configuration for the model's thinking features. "Thinking" is a process where the model breaks down a complex task into smaller, manageable steps. This allows the model to reason about the task, plan its approach, and execute the plan to generate a high-quality response.
  public struct GenerationConfigThinkingConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. If true, the model will include its thoughts in the response. "Thoughts" are the intermediate steps the model takes to arrive at the final response. They can provide insights into the model's reasoning process and help with debugging. If this is true, thoughts are returned only when available.
    public var includeThoughts: Bool?
    
    /// Optional. The token budget for the model's thinking process. The model will make a best effort to stay within this budget. This can be used to control the trade-off between response quality and latency.
    public var thinkingBudget: Int?
    
    /// Optional. The number of thoughts tokens that the model should generate.
    public var thinkingLevel: ThinkingLevel?
    
    /// Creates a new `GenerationConfigThinkingConfig`.
    public init(
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
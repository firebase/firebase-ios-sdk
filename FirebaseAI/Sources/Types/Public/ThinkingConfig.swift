// Copyright 2025 Google LLC
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

/// Configuration for controlling the "thinking" behavior of compatible Gemini models.
///
/// Certain models, like Gemini 2.5 Flash and Pro, utilize a thinking process before generating a
/// response. This allows them to reason through complex problems and plan a more coherent and
/// accurate answer.
public struct ThinkingConfig: Sendable {
  /// The thinking budget in tokens.
  ///
  /// This parameter sets an upper limit on the number of tokens the model can use for its internal
  /// "thinking" process. A higher budget may result in better quality responses for complex tasks
  /// but can also increase latency and cost.
  ///
  /// If you don't specify a budget (`nil`), the model will automatically determine the appropriate
  /// amount of thinking based on the complexity of the prompt.
  ///
  /// **Model-Specific Behavior:**
  /// - **Gemini 2.5 Flash:** The budget can range from `0` to `24576`. Setting the budget to `0`
  ///   disables the thinking process, which prioritizes the lowest latency and cost.
  /// - **Gemini 2.5 Pro:** The budget must be an integer between `128` and `32768`. Thinking cannot
  ///   be disabled for this model.
  ///
  /// An error will be thrown if you set a thinking budget for a model that does not support this
  /// feature or if the specified budget is not within the model's supported range.
  let thinkingBudget: Int?

  /// Whether summaries of the model's "thoughts" are included in responses.
  ///
  /// When `includeThoughts` is set to `true`, the model will return a summary of its internal
  /// thinking process alongside the final answer. This can provide valuable insight into how the
  /// model arrived at its conclusion, which is particularly useful for complex or creative tasks.
  ///
  /// If you don't specify a value for `includeThoughts` (`nil`), the model will use its default
  /// behavior (which is typically to not include thought summaries).
  let includeThoughts: Bool?

  /// Initializes a new `ThinkingConfig`.
  ///
  /// - Parameters:
  ///   - thinkingBudget: The maximum number of tokens to be used for the model's thinking process.
  ///   - includeThoughts: If true, summaries of the model's "thoughts" are included in responses.
  public init(thinkingBudget: Int? = nil, includeThoughts: Bool? = nil) {
    self.thinkingBudget = thinkingBudget
    self.includeThoughts = includeThoughts
  }
}

// MARK: - Codable Conformances

extension ThinkingConfig: Encodable {}

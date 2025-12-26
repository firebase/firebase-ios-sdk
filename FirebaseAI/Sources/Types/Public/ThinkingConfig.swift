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
/// Gemini 2.5 series models and newer utilize a thinking process before generating a response. This
/// allows them to reason through complex problems and plan a more coherent and accurate answer.
/// See the [thinking documentation](https://firebase.google.com/docs/ai-logic/thinking) for more
/// details.
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
  /// An error will be thrown if you set a thinking budget for a model that does not support this
  /// feature or if the specified budget is not within the model's supported range.
  let thinkingBudget: Int?

  /// The level of thoughts tokens that the model should generate.
  let thinkingLevel: ThinkingLevel?

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
  ///     The range of [supported thinking budget values
  ///     ](https://firebase.google.com/docs/ai-logic/thinking#supported-thinking-budget-values)
  ///     depends on the model.
  ///       - To use the default thinking budget or thinking level for a model, set this value to
  ///         `nil` or omit it.
  ///       - To disable thinking, when supported by the model, set this value to `0`.
  ///       - To use dynamic thinking, allowing the model to decide on the thinking budget based on
  ///         the task, set this value to `-1`.
  ///   - includeThoughts: If true, summaries of the model's "thoughts" are included in responses.
  public init(thinkingBudget: Int? = nil, includeThoughts: Bool? = nil) {
    self.thinkingBudget = thinkingBudget
    thinkingLevel = nil
    self.includeThoughts = includeThoughts
  }

  /// Initializes a `ThinkingConfig` with a ``ThinkingLevel``.
  ///
  /// If you don't specify a thinking level, Gemini will use the model's default dynamic thinking
  /// level.
  ///
  /// > Important: Gemini 2.5 series models do not support thinking levels; use
  /// > ``init(thinkingBudget:includeThoughts:)`` to set a thinking budget instead.
  ///
  /// - Parameters:
  ///   - thinkingLevel: A preset that controls the model's "thinking" process. Use
  ///     ``ThinkingLevel/low`` for faster responses on less complex tasks, and
  ///     ``ThinkingLevel/high`` for better reasoning on more complex tasks.
  ///   - includeThoughts: If true, summaries of the model's "thoughts" are included in responses.
  public init(thinkingLevel: ThinkingLevel, includeThoughts: Bool? = nil) {
    thinkingBudget = nil
    self.thinkingLevel = thinkingLevel
    self.includeThoughts = includeThoughts
  }
}

public extension ThinkingConfig {
  /// A preset that balances the trade-off between reasoning quality and response speed for a
  /// model's "thinking" process.
  struct ThinkingLevel: EncodableProtoEnum, Equatable {
    enum Kind: String {
      case low = "LOW"
      case high = "HIGH"
    }

    /// A low thinking level optimized for speed and efficiency.
    ///
    /// This level is suitable for tasks that are less complex and do not require deep reasoning. It
    /// provides a faster response time and lower computational cost.
    public static let low = ThinkingLevel(kind: .low)

    /// A high thinking level designed for complex tasks that require deep reasoning and planning.
    ///
    /// This level may result in higher quality, more coherent, and accurate responses, but with
    /// increased latency and computational cost.
    public static let high = ThinkingLevel(kind: .high)

    var rawValue: String
  }
}

// MARK: - Codable Conformances

extension ThinkingConfig: Encodable {}

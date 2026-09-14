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

/// Statistics on the interaction request's token usage.
package struct Usage: Codable, Sendable, Equatable, Hashable {

  /// A breakdown of cached token usage by modality.
  package let cachedTokensByModality: [ModalityTokens]?

  /// Grounding tool count.
  package let groundingToolCount: [GroundingToolCount]?

  /// A breakdown of input token usage by modality.
  package let inputTokensByModality: [ModalityTokens]?

  /// A breakdown of output token usage by modality.
  package let outputTokensByModality: [ModalityTokens]?

  /// A breakdown of tool-use token usage by modality.
  package let toolUseTokensByModality: [ModalityTokens]?

  /// Number of tokens in the cached part of the prompt (the cached content).
  package let totalCachedTokens: Int?

  /// Number of tokens in the prompt (context).
  package let totalInputTokens: Int?

  /// Total number of tokens across all the generated responses.
  package let totalOutputTokens: Int?

  /// Number of tokens of thoughts for thinking models.
  package let totalThoughtTokens: Int?

  /// Total token count for the interaction request (prompt + responses + other
  /// internal tokens).
  package let totalTokens: Int?

  /// Number of tokens present in tool-use prompt(s).
  package let totalToolUseTokens: Int?

  /// Creates a new `Usage`.
  ///
  /// - Parameters:
  ///   - cachedTokensByModality: A breakdown of cached token usage by modality.
  ///   - groundingToolCount: Grounding tool count.
  ///   - inputTokensByModality: A breakdown of input token usage by modality.
  ///   - outputTokensByModality: A breakdown of output token usage by modality.
  ///   - toolUseTokensByModality: A breakdown of tool-use token usage by modality.
  ///   - totalCachedTokens: Number of tokens in the cached part of the prompt (the cached content).
  ///   - totalInputTokens: Number of tokens in the prompt (context).
  ///   - totalOutputTokens: Total number of tokens across all the generated responses.
  ///   - totalThoughtTokens: Number of tokens of thoughts for thinking models.
  ///   - totalTokens: Total token count for the interaction request (prompt + responses + other
  ///   - totalToolUseTokens: Number of tokens present in tool-use prompt(s).
  package init(
    cachedTokensByModality: [ModalityTokens]? = nil,
    groundingToolCount: [GroundingToolCount]? = nil,
    inputTokensByModality: [ModalityTokens]? = nil,
    outputTokensByModality: [ModalityTokens]? = nil,
    toolUseTokensByModality: [ModalityTokens]? = nil,
    totalCachedTokens: Int? = nil,
    totalInputTokens: Int? = nil,
    totalOutputTokens: Int? = nil,
    totalThoughtTokens: Int? = nil,
    totalTokens: Int? = nil,
    totalToolUseTokens: Int? = nil
  ) {
    self.cachedTokensByModality = cachedTokensByModality
    self.groundingToolCount = groundingToolCount
    self.inputTokensByModality = inputTokensByModality
    self.outputTokensByModality = outputTokensByModality
    self.toolUseTokensByModality = toolUseTokensByModality
    self.totalCachedTokens = totalCachedTokens
    self.totalInputTokens = totalInputTokens
    self.totalOutputTokens = totalOutputTokens
    self.totalThoughtTokens = totalThoughtTokens
    self.totalTokens = totalTokens
    self.totalToolUseTokens = totalToolUseTokens
  }
  enum CodingKeys: String, CodingKey {
    case cachedTokensByModality = "cached_tokens_by_modality"
    case groundingToolCount = "grounding_tool_count"
    case inputTokensByModality = "input_tokens_by_modality"
    case outputTokensByModality = "output_tokens_by_modality"
    case toolUseTokensByModality = "tool_use_tokens_by_modality"
    case totalCachedTokens = "total_cached_tokens"
    case totalInputTokens = "total_input_tokens"
    case totalOutputTokens = "total_output_tokens"
    case totalThoughtTokens = "total_thought_tokens"
    case totalTokens = "total_tokens"
    case totalToolUseTokens = "total_tool_use_tokens"
  }
}

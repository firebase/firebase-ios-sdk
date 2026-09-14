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

/// Configuration for the Antigravity agent runtime.
/// Provides server-side control over the agent's execution environment
/// and tool configuration.
package struct AntigravityAgentConfig: Codable, Sendable, Equatable, Hashable {

  /// Max total tokens for the agent run.
  package let maxTotalTokens: String?

  /// The model to use for agent reasoning.
  package let model: String?

  package let type: String?

  /// Creates a new `AntigravityAgentConfig`.
  ///
  /// - Parameters:
  ///   - maxTotalTokens: Max total tokens for the agent run.
  ///   - model: The model to use for agent reasoning.
  package init(
    maxTotalTokens: String? = nil,
    model: String? = nil
  ) {
    self.maxTotalTokens = maxTotalTokens
    self.model = model
    self.type = "antigravity"
  }
  enum CodingKeys: String, CodingKey {
    case maxTotalTokens = "max_total_tokens"
    case model = "model"
    case type = "type"
  }
}

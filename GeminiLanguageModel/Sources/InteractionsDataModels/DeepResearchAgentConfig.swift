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

/// Configuration for the Deep Research agent.
package struct DeepResearchAgentConfig: Codable, Sendable, Equatable, Hashable {

  /// Enables human-in-the-loop planning for the Deep Research agent. If set to
  /// true, the Deep Research agent will provide a research plan in its response.
  /// The agent will then proceed only if the user confirms the plan in the next
  /// turn.
  package let collaborativePlanning: Bool?

  /// Whether to include thought summaries in the response.
  package let thinkingSummaries: ThinkingSummaries?

  package let type: String?

  /// Whether to include visualizations in the response.
  package let visualization: Visualization?

  /// Creates a new `DeepResearchAgentConfig`.
  ///
  /// - Parameters:
  ///   - collaborativePlanning: Enables human-in-the-loop planning for the Deep Research agent. If set to
  ///   - thinkingSummaries: Whether to include thought summaries in the response.
  ///   - visualization: Whether to include visualizations in the response.
  package init(
    collaborativePlanning: Bool? = nil,
    thinkingSummaries: ThinkingSummaries? = nil,
    visualization: Visualization? = nil
  ) {
    self.collaborativePlanning = collaborativePlanning
    self.thinkingSummaries = thinkingSummaries
    self.type = "deep-research"
    self.visualization = visualization
  }
  enum CodingKeys: String, CodingKey {
    case collaborativePlanning = "collaborative_planning"
    case thinkingSummaries = "thinking_summaries"
    case type = "type"
    case visualization = "visualization"
  }
}

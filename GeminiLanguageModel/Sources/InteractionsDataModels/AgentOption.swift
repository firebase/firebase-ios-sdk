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

/// The agent to interact with.
package enum AgentOption: Codable, Sendable, Equatable, Hashable {

  /// Gemini Deep Research Agent
  case deepResearchProPreview122025

  /// Gemini Deep Research Agent
  case deepResearchPreview042026

  /// Gemini Deep Research Max Agent
  case deepResearchMaxPreview042026

  /// Use the Antigravity managed agent to perform multi-step tasks that require reasoning, file operations, and tool use.
  case antigravityPreview052026

  /// Unrecognized case.
  ///
  /// - Parameter value: The raw string value of the unrecognized enum case.
  case unrecognized(_ value: String)
}

// MARK: - RawRepresentable Conformance

extension AgentOption: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .deepResearchProPreview122025: "deep-research-pro-preview-12-2025"
    case .deepResearchPreview042026: "deep-research-preview-04-2026"
    case .deepResearchMaxPreview042026: "deep-research-max-preview-04-2026"
    case .antigravityPreview052026: "antigravity-preview-05-2026"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "deep-research-pro-preview-12-2025": self = .deepResearchProPreview122025
    case "deep-research-preview-04-2026": self = .deepResearchPreview042026
    case "deep-research-max-preview-04-2026": self = .deepResearchMaxPreview042026
    case "antigravity-preview-05-2026": self = .antigravityPreview052026
    default: self = .unrecognized(rawValue)
    }
  }
}

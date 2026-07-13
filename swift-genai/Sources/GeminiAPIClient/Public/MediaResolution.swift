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
package import GoogleAIDataModels
package import AgentPlatformDataModels

/// Quality resolution options for media.
public enum MediaResolution: Codable, Sendable, Equatable, Hashable {
  case low
  case medium
  case high
  /// - Note: Only supported on AgentPlatform backend for image inputs.
  case ultraHigh
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension MediaResolution {
  package func toGoogleAI() -> GoogleAI.GenerationConfig.MediaResolution {
    switch self {
    case .low: .low
    case .medium: .medium
    case .high, .ultraHigh: .high
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI res: GoogleAI.GenerationConfig.MediaResolution) {
    switch res {
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension MediaResolution {
  package func toAgentPlatformMediaResolution() -> AgentPlatform.GenerationConfig.MediaResolution {
    switch self {
    case .low: .low
    case .medium: .medium
    case .high, .ultraHigh: .high
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform res: AgentPlatform.GenerationConfig.MediaResolution) {
    switch res {
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }

  package func toAgentPlatform() -> AgentPlatform.PartMediaResolution.Level {
    switch self {
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .ultraHigh: .ultraHigh
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform level: AgentPlatform.PartMediaResolution.Level) {
    switch level {
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .ultraHigh: self = .ultraHigh
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

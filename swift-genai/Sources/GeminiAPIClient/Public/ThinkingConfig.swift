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
// See the License for the 1.0 license.

import Foundation
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// Configuration options for thinking features.
public struct ThinkingConfig: Codable, Sendable, Equatable, Hashable {
  public var includeThoughts: Bool?
  public var thinkingBudget: Int?
  public var thinkingLevel: ThinkingLevel?

  public init(
    includeThoughts: Bool? = nil,
    thinkingBudget: Int? = nil,
    thinkingLevel: ThinkingLevel? = nil
  ) {
    self.includeThoughts = includeThoughts
    self.thinkingBudget = thinkingBudget
    self.thinkingLevel = thinkingLevel
  }
}

extension ThinkingConfig {
  public enum ThinkingLevel: Codable, Sendable, Equatable, Hashable {
    case minimal
    case low
    case medium
    case high
    case unrecognized(_ value: String)
  }
}

// MARK: - GoogleAI Mappings

extension ThinkingConfig {
  package func toGoogleAI() -> GoogleAI.ThinkingConfig {
    GoogleAI.ThinkingConfig(
      includeThoughts: includeThoughts,
      thinkingBudget: thinkingBudget,
      thinkingLevel: thinkingLevel?.toGoogleAI()
    )
  }

  package init(fromGoogleAI tc: GoogleAI.ThinkingConfig) {
    self.includeThoughts = tc.includeThoughts
    self.thinkingBudget = tc.thinkingBudget
    self.thinkingLevel = tc.thinkingLevel.map { ThinkingLevel(fromGoogleAI: $0) }
  }
}

extension ThinkingConfig.ThinkingLevel {
  package func toGoogleAI() -> GoogleAI.ThinkingConfig.ThinkingLevel {
    switch self {
    case .minimal: .minimal
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI level: GoogleAI.ThinkingConfig.ThinkingLevel) {
    switch level {
    case .minimal: self = .minimal
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension ThinkingConfig {
  package func toAgentPlatform() -> AgentPlatform.GenerationConfigThinkingConfig {
    AgentPlatform.GenerationConfigThinkingConfig(
      includeThoughts: includeThoughts,
      thinkingBudget: thinkingBudget,
      thinkingLevel: thinkingLevel?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform tc: AgentPlatform.GenerationConfigThinkingConfig) {
    self.includeThoughts = tc.includeThoughts
    self.thinkingBudget = tc.thinkingBudget
    self.thinkingLevel = tc.thinkingLevel.map { ThinkingLevel(fromAgentPlatform: $0) }
  }
}

extension ThinkingConfig.ThinkingLevel {
  package func toAgentPlatform() -> AgentPlatform.GenerationConfigThinkingConfig.ThinkingLevel {
    switch self {
    case .minimal: .minimal
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform level: AgentPlatform.GenerationConfigThinkingConfig.ThinkingLevel) {
    switch level {
    case .minimal: self = .minimal
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

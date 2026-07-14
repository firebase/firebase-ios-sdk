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
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// Prompt feedback response.
public struct PromptFeedback: Codable, Sendable, Equatable, Hashable {
  public var blockReason: BlockReason?
  public var safetyRatings: [SafetyRating]?
  /// - Note: Only supported on AgentPlatform backend.
  public var blockReasonMessage: String?

  public init(
    blockReason: BlockReason? = nil,
    safetyRatings: [SafetyRating]? = nil,
    blockReasonMessage: String? = nil
  ) {
    self.blockReason = blockReason
    self.safetyRatings = safetyRatings
    self.blockReasonMessage = blockReasonMessage
  }
}

public enum BlockReason: Codable, Sendable, Equatable, Hashable {
  case safety
  case other
  case blocklist
  case prohibitedContent
  case modelArmor
  case imageSafety
  case jailbreak
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension PromptFeedback {
  package func toGoogleAI() -> GoogleAI.PromptFeedback {
    GoogleAI.PromptFeedback(
      blockReason: blockReason?.toGoogleAI(),
      safetyRatings: safetyRatings?.map { $0.toGoogleAI() }
    )
  }

  package init(fromGoogleAI feedback: GoogleAI.PromptFeedback) {
    self.blockReason = feedback.blockReason.map { BlockReason(fromGoogleAI: $0) }
    self.safetyRatings = feedback.safetyRatings?.map { SafetyRating(fromGoogleAI: $0) }
    self.blockReasonMessage = nil
  }
}

extension BlockReason {
  package func toGoogleAI() -> GoogleAI.PromptFeedback.BlockReason {
    switch self {
    case .safety: .safety
    case .other: .other
    case .blocklist: .blocklist
    case .prohibitedContent: .prohibitedContent
    case .modelArmor: .unrecognized("MODEL_ARMOR")
    case .imageSafety: .imageSafety
    case .jailbreak: .unrecognized("JAILBREAK")
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI reason: GoogleAI.PromptFeedback.BlockReason) {
    switch reason {
    case .safety: self = .safety
    case .other: self = .other
    case .blocklist: self = .blocklist
    case .prohibitedContent: self = .prohibitedContent
    case .imageSafety: self = .imageSafety
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension PromptFeedback {
  package func toAgentPlatform() -> AgentPlatform.GenerateContentResponsePromptFeedback {
    AgentPlatform.GenerateContentResponsePromptFeedback(
      blockReason: blockReason?.toAgentPlatform(),
      blockReasonMessage: blockReasonMessage,
      safetyRatings: safetyRatings?.map { $0.toAgentPlatform() }
    )
  }

  package init(fromAgentPlatform feedback: AgentPlatform.GenerateContentResponsePromptFeedback) {
    self.blockReason = feedback.blockReason.map { BlockReason(fromAgentPlatform: $0) }
    self.safetyRatings = feedback.safetyRatings?.map { SafetyRating(fromAgentPlatform: $0) }
    self.blockReasonMessage = feedback.blockReasonMessage
  }
}

extension BlockReason {
  package func toAgentPlatform() -> AgentPlatform.GenerateContentResponsePromptFeedback.BlockReason {
    switch self {
    case .safety: .safety
    case .other: .other
    case .blocklist: .blocklist
    case .prohibitedContent: .prohibitedContent
    case .modelArmor: .modelArmor
    case .imageSafety: .imageSafety
    case .jailbreak: .jailbreak
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform reason: AgentPlatform.GenerateContentResponsePromptFeedback.BlockReason) {
    switch reason {
    case .safety: self = .safety
    case .other: self = .other
    case .blocklist: self = .blocklist
    case .prohibitedContent: self = .prohibitedContent
    case .modelArmor: self = .modelArmor
    case .imageSafety: self = .imageSafety
    case .jailbreak: self = .jailbreak
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

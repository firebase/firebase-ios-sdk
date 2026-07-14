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
package import InternalSharedDataModels
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// A candidate response from the model.
public struct Candidate: Codable, Sendable, Equatable, Hashable {
  public var avgLogprobs: Double?
  public var content: GeminiContent?
  public var finishMessage: String?
  public var finishReason: FinishReason?
  public var index: Int?
  public var safetyRatings: [SafetyRating]?

  // Unified metadata fields (optional wrappers)
  package var citationMetadata: InternalGoogleAIDataModels.GoogleAI.CitationMetadata?
  package var groundingMetadata: InternalGoogleAIDataModels.GoogleAI.GroundingMetadata?
  package var urlContextMetadata: InternalGoogleAIDataModels.GoogleAI.UrlContextMetadata?

  public init(
    avgLogprobs: Double? = nil,
    content: GeminiContent? = nil,
    finishMessage: String? = nil,
    finishReason: FinishReason? = nil,
    index: Int? = nil,
    safetyRatings: [SafetyRating]? = nil
  ) {
    self.avgLogprobs = avgLogprobs
    self.content = content
    self.finishMessage = finishMessage
    self.finishReason = finishReason
    self.index = index
    self.safetyRatings = safetyRatings
    self.citationMetadata = nil
    self.groundingMetadata = nil
    self.urlContextMetadata = nil
  }

  package init(
    avgLogprobs: Double? = nil,
    content: GeminiContent? = nil,
    finishMessage: String? = nil,
    finishReason: FinishReason? = nil,
    index: Int? = nil,
    safetyRatings: [SafetyRating]? = nil,
    citationMetadata: InternalGoogleAIDataModels.GoogleAI.CitationMetadata? = nil,
    groundingMetadata: InternalGoogleAIDataModels.GoogleAI.GroundingMetadata? = nil,
    urlContextMetadata: InternalGoogleAIDataModels.GoogleAI.UrlContextMetadata? = nil
  ) {
    self.avgLogprobs = avgLogprobs
    self.content = content
    self.finishMessage = finishMessage
    self.finishReason = finishReason
    self.index = index
    self.safetyRatings = safetyRatings
    self.citationMetadata = citationMetadata
    self.groundingMetadata = groundingMetadata
    self.urlContextMetadata = urlContextMetadata
  }
}

public enum FinishReason: Codable, Sendable, Equatable, Hashable {
  case stop
  case maxTokens
  case safety
  case recitation
  case other
  case blocklist
  case prohibitedContent
  case spii
  case malformedFunctionCall
  case modelArmor
  case imageSafety
  case imageProhibitedContent
  case imageRecitation
  case imageOther
  case unexpectedToolCall
  case noImage
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension Candidate {
  package func toGoogleAI() -> GoogleAI.Candidate {
    GoogleAI.Candidate(
      avgLogprobs: avgLogprobs,
      citationMetadata: citationMetadata,
      content: content?.toGoogleAI(),
      finishMessage: finishMessage,
      finishReason: finishReason?.toGoogleAI(),
      groundingAttributions: nil,
      groundingMetadata: groundingMetadata,
      index: index,
      logprobsResult: nil,
      safetyRatings: safetyRatings?.map { $0.toGoogleAI() },
      tokenCount: nil,
      urlContextMetadata: urlContextMetadata
    )
  }

  package init(fromGoogleAI cand: GoogleAI.Candidate) {
    self.avgLogprobs = cand.avgLogprobs
    self.content = cand.content.map { GeminiContent(fromGoogleAI: $0) }
    self.finishMessage = cand.finishMessage
    self.finishReason = cand.finishReason.map { FinishReason(fromGoogleAI: $0) }
    self.index = cand.index
    self.safetyRatings = cand.safetyRatings?.map { SafetyRating(fromGoogleAI: $0) }
    self.citationMetadata = cand.citationMetadata
    self.groundingMetadata = cand.groundingMetadata
    self.urlContextMetadata = cand.urlContextMetadata
  }
}

extension FinishReason {
  package func toGoogleAI() -> GoogleAI.Candidate.FinishReason {
    switch self {
    case .stop: .stop
    case .maxTokens: .maxTokens
    case .safety: .safety
    case .recitation: .recitation
    case .other: .other
    case .blocklist: .blocklist
    case .prohibitedContent: .prohibitedContent
    case .spii: .spii
    case .malformedFunctionCall: .malformedFunctionCall
    case .modelArmor: .unrecognized("MODEL_ARMOR")
    case .imageSafety: .imageSafety
    case .imageProhibitedContent: .imageProhibitedContent
    case .imageRecitation: .imageRecitation
    case .imageOther: .imageOther
    case .unexpectedToolCall: .unexpectedToolCall
    case .noImage: .noImage
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI reason: GoogleAI.Candidate.FinishReason) {
    switch reason {
    case .stop: self = .stop
    case .maxTokens: self = .maxTokens
    case .safety: self = .safety
    case .recitation: self = .recitation
    case .language: self = .other
    case .other: self = .other
    case .blocklist: self = .blocklist
    case .prohibitedContent: self = .prohibitedContent
    case .spii: self = .spii
    case .malformedFunctionCall: self = .malformedFunctionCall
    case .imageSafety: self = .imageSafety
    case .imageProhibitedContent: self = .imageProhibitedContent
    case .imageOther: self = .imageOther
    case .noImage: self = .noImage
    case .imageRecitation: self = .imageRecitation
    case .unexpectedToolCall: self = .unexpectedToolCall
    case .tooManyToolCalls: self = .other
    case .missingThoughtSignature: self = .other
    case .malformedResponse: self = .other
    case .escalation: self = .other
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension Candidate {
  package func toAgentPlatform() -> AgentPlatform.Candidate {
    let apCitation = citationMetadata.flatMap { try? AgentPlatform.CitationMetadata(from: JSONDecoder().decode(GoogleAI.CitationMetadata.self, from: JSONEncoder().encode($0)) as! Decoder) }
    let apGrounding = groundingMetadata.flatMap { try? AgentPlatform.GroundingMetadata(from: JSONDecoder().decode(GoogleAI.GroundingMetadata.self, from: JSONEncoder().encode($0)) as! Decoder) }
    let apUrlContext = urlContextMetadata.flatMap { try? AgentPlatform.UrlContextMetadata(from: JSONDecoder().decode(GoogleAI.UrlContextMetadata.self, from: JSONEncoder().encode($0)) as! Decoder) }

    return AgentPlatform.Candidate(
      avgLogprobs: avgLogprobs,
      citationMetadata: apCitation,
      content: content?.toAgentPlatform(),
      finishMessage: finishMessage,
      finishReason: finishReason?.toAgentPlatform(),
      groundingMetadata: apGrounding,
      index: index,
      logprobsResult: nil,
      safetyRatings: safetyRatings?.map { $0.toAgentPlatform() },
      urlContextMetadata: apUrlContext
    )
  }

  package init(fromAgentPlatform cand: AgentPlatform.Candidate) {
    self.avgLogprobs = cand.avgLogprobs
    self.content = cand.content.map { GeminiContent(fromAgentPlatform: $0) }
    self.finishMessage = cand.finishMessage
    self.finishReason = cand.finishReason.map { FinishReason(fromAgentPlatform: $0) }
    self.index = cand.index
    self.safetyRatings = cand.safetyRatings?.map { SafetyRating(fromAgentPlatform: $0) }

    self.citationMetadata = cand.citationMetadata.flatMap { try? GoogleAI.CitationMetadata(from: JSONDecoder().decode(AgentPlatform.CitationMetadata.self, from: JSONEncoder().encode($0)) as! Decoder) }
    self.groundingMetadata = cand.groundingMetadata.flatMap { try? GoogleAI.GroundingMetadata(from: JSONDecoder().decode(AgentPlatform.GroundingMetadata.self, from: JSONEncoder().encode($0)) as! Decoder) }
    self.urlContextMetadata = cand.urlContextMetadata.flatMap { try? GoogleAI.UrlContextMetadata(from: JSONDecoder().decode(AgentPlatform.UrlContextMetadata.self, from: JSONEncoder().encode($0)) as! Decoder) }
  }
}

extension FinishReason {
  package func toAgentPlatform() -> AgentPlatform.Candidate.FinishReason {
    switch self {
    case .stop: .stop
    case .maxTokens: .maxTokens
    case .safety: .safety
    case .recitation: .recitation
    case .other: .other
    case .blocklist: .blocklist
    case .prohibitedContent: .prohibitedContent
    case .spii: .spii
    case .malformedFunctionCall: .malformedFunctionCall
    case .modelArmor: .modelArmor
    case .imageSafety: .imageSafety
    case .imageProhibitedContent: .imageProhibitedContent
    case .imageRecitation: .imageRecitation
    case .imageOther: .imageOther
    case .unexpectedToolCall: .unexpectedToolCall
    case .noImage: .noImage
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform reason: AgentPlatform.Candidate.FinishReason) {
    switch reason {
    case .stop: self = .stop
    case .maxTokens: self = .maxTokens
    case .safety: self = .safety
    case .recitation: self = .recitation
    case .other: self = .other
    case .blocklist: self = .blocklist
    case .prohibitedContent: self = .prohibitedContent
    case .spii: self = .spii
    case .malformedFunctionCall: self = .malformedFunctionCall
    case .modelArmor: self = .modelArmor
    case .imageSafety: self = .imageSafety
    case .imageProhibitedContent: self = .imageProhibitedContent
    case .imageRecitation: self = .imageRecitation
    case .imageOther: self = .imageOther
    case .unexpectedToolCall: self = .unexpectedToolCall
    case .noImage: self = .noImage
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

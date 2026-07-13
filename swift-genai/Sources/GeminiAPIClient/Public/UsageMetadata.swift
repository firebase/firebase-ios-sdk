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

/// Metadata on token usage.
public struct UsageMetadata: Codable, Sendable, Equatable, Hashable {
  public var cacheTokensDetails: [ModalityTokenCount]?
  public var cachedContentTokenCount: Int?
  public var candidatesTokenCount: Int?
  public var candidatesTokensDetails: [ModalityTokenCount]?
  public var promptTokenCount: Int?
  public var promptTokensDetails: [ModalityTokenCount]?
  public var thoughtsTokenCount: Int?
  public var toolUsePromptTokenCount: Int?
  public var toolUsePromptTokensDetails: [ModalityTokenCount]?
  public var totalTokenCount: Int?

  /// - Note: Only supported on GoogleAI backend.
  public var serviceTier: ServiceTier?

  /// - Note: Only supported on AgentPlatform backend.
  public var trafficType: TrafficType?

  public init(
    cacheTokensDetails: [ModalityTokenCount]? = nil,
    cachedContentTokenCount: Int? = nil,
    candidatesTokenCount: Int? = nil,
    candidatesTokensDetails: [ModalityTokenCount]? = nil,
    promptTokenCount: Int? = nil,
    promptTokensDetails: [ModalityTokenCount]? = nil,
    thoughtsTokenCount: Int? = nil,
    toolUsePromptTokenCount: Int? = nil,
    toolUsePromptTokensDetails: [ModalityTokenCount]? = nil,
    totalTokenCount: Int? = nil,
    serviceTier: ServiceTier? = nil,
    trafficType: TrafficType? = nil
  ) {
    self.cacheTokensDetails = cacheTokensDetails
    self.cachedContentTokenCount = cachedContentTokenCount
    self.candidatesTokenCount = candidatesTokenCount
    self.candidatesTokensDetails = candidatesTokensDetails
    self.promptTokenCount = promptTokenCount
    self.promptTokensDetails = promptTokensDetails
    self.thoughtsTokenCount = thoughtsTokenCount
    self.toolUsePromptTokenCount = toolUsePromptTokenCount
    self.toolUsePromptTokensDetails = toolUsePromptTokensDetails
    self.totalTokenCount = totalTokenCount
    self.serviceTier = serviceTier
    self.trafficType = trafficType
  }
}

public struct ModalityTokenCount: Codable, Sendable, Equatable, Hashable {
  public var modality: Modality?
  public var tokenCount: Int?

  public init(modality: Modality? = nil, tokenCount: Int? = nil) {
    self.modality = modality
    self.tokenCount = tokenCount
  }
}

public enum Modality: Codable, Sendable, Equatable, Hashable {
  case text
  case image
  case audio
  case video
  case document
  case unrecognized(_ value: String)
}

public enum TrafficType: Codable, Sendable, Equatable, Hashable {
  case onDemand
  case onDemandPriority
  case onDemandFlex
  case provisionedThroughput
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension UsageMetadata {
  package func toGoogleAI() -> GoogleAI.UsageMetadata {
    GoogleAI.UsageMetadata(
      cacheTokensDetails: cacheTokensDetails?.map { $0.toGoogleAI() },
      cachedContentTokenCount: cachedContentTokenCount,
      candidatesTokenCount: candidatesTokenCount,
      candidatesTokensDetails: candidatesTokensDetails?.map { $0.toGoogleAI() },
      promptTokenCount: promptTokenCount,
      promptTokensDetails: promptTokensDetails?.map { $0.toGoogleAI() },
      serviceTier: serviceTier?.toGoogleAIUsageServiceTier(),
      thoughtsTokenCount: thoughtsTokenCount,
      toolUsePromptTokenCount: toolUsePromptTokenCount,
      toolUsePromptTokensDetails: toolUsePromptTokensDetails?.map { $0.toGoogleAI() },
      totalTokenCount: totalTokenCount
    )
  }

  package init(fromGoogleAI metadata: GoogleAI.UsageMetadata) {
    self.cacheTokensDetails = metadata.cacheTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) }
    self.cachedContentTokenCount = metadata.cachedContentTokenCount
    self.candidatesTokenCount = metadata.candidatesTokenCount
    self.candidatesTokensDetails = metadata.candidatesTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) }
    self.promptTokenCount = metadata.promptTokenCount
    self.promptTokensDetails = metadata.promptTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) }
    self.thoughtsTokenCount = metadata.thoughtsTokenCount
    self.toolUsePromptTokenCount = metadata.toolUsePromptTokenCount
    self.toolUsePromptTokensDetails = metadata.toolUsePromptTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) }
    self.totalTokenCount = metadata.totalTokenCount
    self.serviceTier = metadata.serviceTier.map { ServiceTier(fromGoogleAIUsageServiceTier: $0) }
    self.trafficType = nil
  }
}

extension ModalityTokenCount {
  package func toGoogleAI() -> GoogleAI.ModalityTokenCount {
    GoogleAI.ModalityTokenCount(modality: modality?.toGoogleAI(), tokenCount: tokenCount)
  }

  package init(fromGoogleAI val: GoogleAI.ModalityTokenCount) {
    self.tokenCount = val.tokenCount
    self.modality = val.modality.map { Modality(fromGoogleAI: $0) }
  }
}

extension Modality {
  package func toGoogleAI() -> GoogleAI.ModalityTokenCount.Modality {
    switch self {
    case .text: .text
    case .image: .image
    case .audio: .audio
    case .video: .video
    case .document: .document
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.ModalityTokenCount.Modality) {
    switch val {
    case .text: self = .text
    case .image: self = .image
    case .audio: self = .audio
    case .video: self = .video
    case .document: self = .document
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension UsageMetadata {
  package func toAgentPlatform() -> AgentPlatform.GenerateContentResponseUsageMetadata {
    AgentPlatform.GenerateContentResponseUsageMetadata(
      cacheTokensDetails: cacheTokensDetails?.map { $0.toAgentPlatform() },
      cachedContentTokenCount: cachedContentTokenCount,
      candidatesTokenCount: candidatesTokenCount,
      candidatesTokensDetails: candidatesTokensDetails?.map { $0.toAgentPlatform() },
      promptTokenCount: promptTokenCount,
      promptTokensDetails: promptTokensDetails?.map { $0.toAgentPlatform() },
      thoughtsTokenCount: thoughtsTokenCount,
      toolUsePromptTokenCount: toolUsePromptTokenCount,
      toolUsePromptTokensDetails: toolUsePromptTokensDetails?.map { $0.toAgentPlatform() },
      totalTokenCount: totalTokenCount,
      trafficType: trafficType?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform metadata: AgentPlatform.GenerateContentResponseUsageMetadata) {
    self.cacheTokensDetails = metadata.cacheTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) }
    self.cachedContentTokenCount = metadata.cachedContentTokenCount
    self.candidatesTokenCount = metadata.candidatesTokenCount
    self.candidatesTokensDetails = metadata.candidatesTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) }
    self.promptTokenCount = metadata.promptTokenCount
    self.promptTokensDetails = metadata.promptTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) }
    self.thoughtsTokenCount = metadata.thoughtsTokenCount
    self.toolUsePromptTokenCount = metadata.toolUsePromptTokenCount
    self.toolUsePromptTokensDetails = metadata.toolUsePromptTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) }
    self.totalTokenCount = metadata.totalTokenCount
    self.serviceTier = nil
    self.trafficType = metadata.trafficType.map { TrafficType(fromAgentPlatform: $0) }
  }
}

extension ModalityTokenCount {
  package func toAgentPlatform() -> AgentPlatform.ModalityTokenCount {
    AgentPlatform.ModalityTokenCount(modality: modality?.toAgentPlatform(), tokenCount: tokenCount)
  }

  package init(fromAgentPlatform val: AgentPlatform.ModalityTokenCount) {
    self.tokenCount = val.tokenCount
    self.modality = val.modality.map { Modality(fromAgentPlatform: $0) }
  }
}

extension Modality {
  package func toAgentPlatform() -> AgentPlatform.ModalityTokenCount.Modality {
    switch self {
    case .text: .text
    case .image: .image
    case .audio: .audio
    case .video: .video
    case .document: .document
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.ModalityTokenCount.Modality) {
    switch val {
    case .text: self = .text
    case .image: self = .image
    case .audio: self = .audio
    case .video: self = .video
    case .document: self = .document
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension TrafficType {
  package func toAgentPlatform() -> AgentPlatform.GenerateContentResponseUsageMetadata.TrafficType {
    switch self {
    case .onDemand: .onDemand
    case .onDemandPriority: .onDemandPriority
    case .onDemandFlex: .onDemandFlex
    case .provisionedThroughput: .provisionedThroughput
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.GenerateContentResponseUsageMetadata.TrafficType) {
    switch val {
    case .onDemand: self = .onDemand
    case .onDemandPriority: self = .onDemandPriority
    case .onDemandFlex: self = .onDemandFlex
    case .provisionedThroughput: self = .provisionedThroughput
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

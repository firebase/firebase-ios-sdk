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

// MARK: - SafetySetting

/// Safety setting, affecting the safety-blocking behavior.
public struct SafetySetting: Codable, Sendable, Equatable, Hashable {
  /// Required. The category for this setting.
  public var category: SafetyCategory?

  /// Required. Controls the probability threshold at which harm is blocked.
  public var threshold: SafetyThreshold?

  /// Optional. The method for blocking content.
  /// - Note: Only supported on AgentPlatform backend. Excluded on GoogleAI.
  public var method: SafetyMethod?

  public init(
    category: SafetyCategory? = nil,
    threshold: SafetyThreshold? = nil,
    method: SafetyMethod? = nil
  ) {
    self.category = category
    self.threshold = threshold
    self.method = method
  }
}

// MARK: - SafetyCategory

public enum SafetyCategory: Codable, Sendable, Equatable, Hashable {
  // Legacy / PaLM categories (GoogleAI exclusive)
  /// derogatory category
  /// - Note: Only supported on GoogleAI backend.
  case derogatory
  /// toxicity category
  /// - Note: Only supported on GoogleAI backend.
  case toxicity
  /// violence category
  /// - Note: Only supported on GoogleAI backend.
  case violence
  /// sexual category
  /// - Note: Only supported on GoogleAI backend.
  case sexual
  /// medical category
  /// - Note: Only supported on GoogleAI backend.
  case medical
  /// dangerous category
  /// - Note: Only supported on GoogleAI backend.
  case dangerous

  // Core Gemini categories (Common)
  case hateSpeech
  case dangerousContent
  case harassment
  case sexuallyExplicit
  case civicIntegrity
  case jailbreak

  // Image-specific categories (AgentPlatform exclusive)
  /// - Note: Only supported on AgentPlatform backend.
  case imageHate
  /// - Note: Only supported on AgentPlatform backend.
  case imageDangerousContent
  /// - Note: Only supported on AgentPlatform backend.
  case imageHarassment
  /// - Note: Only supported on AgentPlatform backend.
  case imageSexuallyExplicit

  case unrecognized(_ value: String)
}

// MARK: - SafetyThreshold

public enum SafetyThreshold: Codable, Sendable, Equatable, Hashable {
  case blockLowAndAbove
  case blockMediumAndAbove
  case blockOnlyHigh
  case blockNone
  case off
  case unrecognized(_ value: String)
}

// MARK: - SafetyMethod

public enum SafetyMethod: Codable, Sendable, Equatable, Hashable {
  case severity
  case probability
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension SafetySetting {
  package func toGoogleAI() -> GoogleAI.SafetySetting {
    GoogleAI.SafetySetting(
      category: category?.toGoogleAI(),
      threshold: threshold?.toGoogleAI()
    )
  }

  package init(fromGoogleAI setting: GoogleAI.SafetySetting) {
    self.category = setting.category.map { SafetyCategory(fromGoogleAI: $0) }
    self.threshold = setting.threshold.map { SafetyThreshold(fromGoogleAI: $0) }
    self.method = nil
  }
}

extension SafetyCategory {
  package func toGoogleAI() -> GoogleAI.SafetySetting.Category {
    switch self {
    case .derogatory: .derogatory
    case .toxicity: .toxicity
    case .violence: .violence
    case .sexual: .sexual
    case .medical: .medical
    case .dangerous: .dangerous
    case .hateSpeech: .hateSpeech
    case .dangerousContent: .dangerousContent
    case .harassment: .harassment
    case .sexuallyExplicit: .sexuallyExplicit
    case .civicIntegrity: .civicIntegrity
    case .jailbreak: .jailbreak
    case .imageHate: .unrecognized("HARM_CATEGORY_IMAGE_HATE")
    case .imageDangerousContent: .unrecognized("HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT")
    case .imageHarassment: .unrecognized("HARM_CATEGORY_IMAGE_HARASSMENT")
    case .imageSexuallyExplicit: .unrecognized("HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT")
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI category: GoogleAI.SafetySetting.Category) {
    switch category {
    case .derogatory: self = .derogatory
    case .toxicity: self = .toxicity
    case .violence: self = .violence
    case .sexual: self = .sexual
    case .medical: self = .medical
    case .dangerous: self = .dangerous
    case .harassment: self = .harassment
    case .hateSpeech: self = .hateSpeech
    case .sexuallyExplicit: self = .sexuallyExplicit
    case .dangerousContent: self = .dangerousContent
    case .civicIntegrity: self = .civicIntegrity
    case .jailbreak: self = .jailbreak
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension SafetyThreshold {
  package func toGoogleAI() -> GoogleAI.SafetySetting.Threshold {
    switch self {
    case .blockLowAndAbove: .blockLowAndAbove
    case .blockMediumAndAbove: .blockMediumAndAbove
    case .blockOnlyHigh: .blockOnlyHigh
    case .blockNone: .blockNone
    case .off: .off
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI threshold: GoogleAI.SafetySetting.Threshold) {
    switch threshold {
    case .blockLowAndAbove: self = .blockLowAndAbove
    case .blockMediumAndAbove: self = .blockMediumAndAbove
    case .blockOnlyHigh: self = .blockOnlyHigh
    case .blockNone: self = .blockNone
    case .off: self = .off
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension SafetySetting {
  package func toAgentPlatform() -> AgentPlatform.SafetySetting {
    AgentPlatform.SafetySetting(
      category: category?.toAgentPlatform(),
      method: method?.toAgentPlatform(),
      threshold: threshold?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform setting: AgentPlatform.SafetySetting) {
    self.category = setting.category.map { SafetyCategory(fromAgentPlatform: $0) }
    self.threshold = setting.threshold.map { SafetyThreshold(fromAgentPlatform: $0) }
    self.method = setting.method.map { SafetyMethod(fromAgentPlatform: $0) }
  }
}

extension SafetyCategory {
  package func toAgentPlatform() -> AgentPlatform.SafetySetting.Category {
    switch self {
    case .hateSpeech: .hateSpeech
    case .dangerousContent: .dangerousContent
    case .harassment: .harassment
    case .sexuallyExplicit: .sexuallyExplicit
    case .civicIntegrity: .civicIntegrity
    case .imageHate: .imageHate
    case .imageDangerousContent: .imageDangerousContent
    case .imageHarassment: .imageHarassment
    case .imageSexuallyExplicit: .imageSexuallyExplicit
    case .jailbreak: .jailbreak
    case .derogatory: .unrecognized("HARM_CATEGORY_DEROGATORY")
    case .toxicity: .unrecognized("HARM_CATEGORY_TOXICITY")
    case .violence: .unrecognized("HARM_CATEGORY_VIOLENCE")
    case .sexual: .unrecognized("HARM_CATEGORY_SEXUAL")
    case .medical: .unrecognized("HARM_CATEGORY_MEDICAL")
    case .dangerous: .unrecognized("HARM_CATEGORY_DANGEROUS")
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform category: AgentPlatform.SafetySetting.Category) {
    switch category {
    case .hateSpeech: self = .hateSpeech
    case .dangerousContent: self = .dangerousContent
    case .harassment: self = .harassment
    case .sexuallyExplicit: self = .sexuallyExplicit
    case .civicIntegrity: self = .civicIntegrity
    case .imageHate: self = .imageHate
    case .imageDangerousContent: self = .imageDangerousContent
    case .imageHarassment: self = .imageHarassment
    case .imageSexuallyExplicit: self = .imageSexuallyExplicit
    case .jailbreak: self = .jailbreak
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension SafetyThreshold {
  package func toAgentPlatform() -> AgentPlatform.SafetySetting.Threshold {
    switch self {
    case .blockLowAndAbove: .blockLowAndAbove
    case .blockMediumAndAbove: .blockMediumAndAbove
    case .blockOnlyHigh: .blockOnlyHigh
    case .blockNone: .blockNone
    case .off: .off
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform threshold: AgentPlatform.SafetySetting.Threshold) {
    switch threshold {
    case .blockLowAndAbove: self = .blockLowAndAbove
    case .blockMediumAndAbove: self = .blockMediumAndAbove
    case .blockOnlyHigh: self = .blockOnlyHigh
    case .blockNone: self = .blockNone
    case .off: self = .off
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension SafetyMethod {
  package func toAgentPlatform() -> AgentPlatform.SafetySetting.Method {
    switch self {
    case .severity: .severity
    case .probability: .probability
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform method: AgentPlatform.SafetySetting.Method) {
    switch method {
    case .severity: self = .severity
    case .probability: self = .probability
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

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

/// Safety rating for a category.
public struct SafetyRating: Codable, Sendable, Equatable, Hashable {
  public var blocked: Bool?
  public var category: SafetyCategory?
  public var probability: SafetyProbability?

  public init(blocked: Bool? = nil, category: SafetyCategory? = nil, probability: SafetyProbability? = nil) {
    self.blocked = blocked
    self.category = category
    self.probability = probability
  }
}

public enum SafetyProbability: Codable, Sendable, Equatable, Hashable {
  case negligible
  case low
  case medium
  case high
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension SafetyRating {
  package func toGoogleAI() -> GoogleAI.SafetyRating {
    GoogleAI.SafetyRating(
      blocked: blocked,
      category: category?.toGoogleAIRatingCategory(),
      probability: probability?.toGoogleAI()
    )
  }

  package init(fromGoogleAI rating: GoogleAI.SafetyRating) {
    self.blocked = rating.blocked
    self.category = rating.category.map { SafetyCategory(fromGoogleAIRatingCategory: $0) }
    self.probability = rating.probability.map { SafetyProbability(fromGoogleAI: $0) }
  }
}

extension SafetyProbability {
  package func toGoogleAI() -> GoogleAI.SafetyRating.Probability {
    switch self {
    case .negligible: .negligible
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI prob: GoogleAI.SafetyRating.Probability) {
    switch prob {
    case .negligible: self = .negligible
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension SafetyRating {
  package func toAgentPlatform() -> AgentPlatform.SafetyRating {
    AgentPlatform.SafetyRating(
      blocked: blocked,
      category: category?.toAgentPlatformRatingCategory(),
      probability: probability?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform rating: AgentPlatform.SafetyRating) {
    self.blocked = rating.blocked
    self.category = rating.category.map { SafetyCategory(fromAgentPlatformRatingCategory: $0) }
    self.probability = rating.probability.map { SafetyProbability(fromAgentPlatform: $0) }
  }
}

extension SafetyProbability {
  package func toAgentPlatform() -> AgentPlatform.SafetyRating.Probability {
    switch self {
    case .negligible: .negligible
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform prob: AgentPlatform.SafetyRating.Probability) {
    switch prob {
    case .negligible: self = .negligible
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - Category Extra Rating Mappings

extension SafetyCategory {
  package func toGoogleAIRatingCategory() -> GoogleAI.SafetyRating.Category {
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

  package init(fromGoogleAIRatingCategory category: GoogleAI.SafetyRating.Category) {
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

  package func toAgentPlatformRatingCategory() -> AgentPlatform.SafetyRating.Category {
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

  package init(fromAgentPlatformRatingCategory category: AgentPlatform.SafetyRating.Category) {
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

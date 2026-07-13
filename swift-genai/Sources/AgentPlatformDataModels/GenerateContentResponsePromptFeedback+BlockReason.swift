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

extension AgentPlatform.GenerateContentResponsePromptFeedback {
  /// Output only. The reason why the prompt was blocked.
  package enum BlockReason: Codable, Sendable, Equatable, Hashable {
    /// The prompt was blocked for safety reasons.
    case safety
    
    /// The prompt was blocked for other reasons. For example, it may be due to the prompt's language, or because it contains other harmful content.
    case other
    
    /// The prompt was blocked because it contains a term from the terminology blocklist.
    case blocklist
    
    /// The prompt was blocked because it contains prohibited content.
    case prohibitedContent
    
    /// The prompt was blocked by Model Armor.
    case modelArmor
    
    /// The prompt was blocked because it contains content that is unsafe for image generation.
    case imageSafety
    
    /// The prompt was blocked as a jailbreak attempt.
    case jailbreak
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.GenerateContentResponsePromptFeedback.BlockReason: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .safety: "SAFETY"
    case .other: "OTHER"
    case .blocklist: "BLOCKLIST"
    case .prohibitedContent: "PROHIBITED_CONTENT"
    case .modelArmor: "MODEL_ARMOR"
    case .imageSafety: "IMAGE_SAFETY"
    case .jailbreak: "JAILBREAK"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "SAFETY": self = .safety
    case "OTHER": self = .other
    case "BLOCKLIST": self = .blocklist
    case "PROHIBITED_CONTENT": self = .prohibitedContent
    case "MODEL_ARMOR": self = .modelArmor
    case "IMAGE_SAFETY": self = .imageSafety
    case "JAILBREAK": self = .jailbreak
    default: self = .unrecognized(rawValue)
    }
  }
}
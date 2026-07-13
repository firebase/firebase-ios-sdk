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

extension GoogleAI.PromptFeedback {
  /// Optional. If set, the prompt was blocked and no candidates are returned. Rephrase the prompt.
  package enum BlockReason: Codable, Sendable, Equatable, Hashable {
    /// Prompt was blocked due to safety reasons. Inspect `safety_ratings` to understand which safety category blocked it.
    case safety
    
    /// Prompt was blocked due to unknown reasons.
    case other
    
    /// Prompt was blocked due to the terms which are included from the terminology blocklist.
    case blocklist
    
    /// Prompt was blocked due to prohibited content.
    case prohibitedContent
    
    /// Candidates blocked due to unsafe image generation content.
    case imageSafety
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.PromptFeedback.BlockReason: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .safety: "SAFETY"
    case .other: "OTHER"
    case .blocklist: "BLOCKLIST"
    case .prohibitedContent: "PROHIBITED_CONTENT"
    case .imageSafety: "IMAGE_SAFETY"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "SAFETY": self = .safety
    case "OTHER": self = .other
    case "BLOCKLIST": self = .blocklist
    case "PROHIBITED_CONTENT": self = .prohibitedContent
    case "IMAGE_SAFETY": self = .imageSafety
    default: self = .unrecognized(rawValue)
    }
  }
}
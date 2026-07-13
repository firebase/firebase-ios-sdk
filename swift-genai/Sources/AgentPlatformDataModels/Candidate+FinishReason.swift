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

extension AgentPlatform.Candidate {
  /// Output only. The reason why the model stopped generating tokens. If empty, the model has not stopped generating.
  package enum FinishReason: Codable, Sendable, Equatable, Hashable {
    /// The model reached a natural stopping point or a configured stop sequence.
    case stop
    
    /// The model generated the maximum number of tokens allowed by the `max_output_tokens` parameter.
    case maxTokens
    
    /// The model stopped generating because the content potentially violates safety policies. NOTE: When streaming, the `content` field is empty if content filters block the output.
    case safety
    
    /// The model stopped generating because the content may be a recitation from a source.
    case recitation
    
    /// The model stopped generating for a reason not otherwise specified.
    case other
    
    /// The model stopped generating because the content contains a term from a configured blocklist.
    case blocklist
    
    /// The model stopped generating because the content may be prohibited.
    case prohibitedContent
    
    /// The model stopped generating because the content may contain sensitive personally identifiable information (SPII).
    case spii
    
    /// The model generated a function call that is syntactically invalid and can't be parsed.
    case malformedFunctionCall
    
    /// The model response was blocked by Model Armor.
    case modelArmor
    
    /// The generated image potentially violates safety policies.
    case imageSafety
    
    /// The generated image may contain prohibited content.
    case imageProhibitedContent
    
    /// The generated image may be a recitation from a source.
    case imageRecitation
    
    /// The image generation stopped for a reason not otherwise specified.
    case imageOther
    
    /// The model generated a function call that is semantically invalid. This can happen, for example, if function calling is not enabled or the generated function is not in the function declaration.
    case unexpectedToolCall
    
    /// The model was expected to generate an image, but didn't.
    case noImage
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.Candidate.FinishReason: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .stop: "STOP"
    case .maxTokens: "MAX_TOKENS"
    case .safety: "SAFETY"
    case .recitation: "RECITATION"
    case .other: "OTHER"
    case .blocklist: "BLOCKLIST"
    case .prohibitedContent: "PROHIBITED_CONTENT"
    case .spii: "SPII"
    case .malformedFunctionCall: "MALFORMED_FUNCTION_CALL"
    case .modelArmor: "MODEL_ARMOR"
    case .imageSafety: "IMAGE_SAFETY"
    case .imageProhibitedContent: "IMAGE_PROHIBITED_CONTENT"
    case .imageRecitation: "IMAGE_RECITATION"
    case .imageOther: "IMAGE_OTHER"
    case .unexpectedToolCall: "UNEXPECTED_TOOL_CALL"
    case .noImage: "NO_IMAGE"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "STOP": self = .stop
    case "MAX_TOKENS": self = .maxTokens
    case "SAFETY": self = .safety
    case "RECITATION": self = .recitation
    case "OTHER": self = .other
    case "BLOCKLIST": self = .blocklist
    case "PROHIBITED_CONTENT": self = .prohibitedContent
    case "SPII": self = .spii
    case "MALFORMED_FUNCTION_CALL": self = .malformedFunctionCall
    case "MODEL_ARMOR": self = .modelArmor
    case "IMAGE_SAFETY": self = .imageSafety
    case "IMAGE_PROHIBITED_CONTENT": self = .imageProhibitedContent
    case "IMAGE_RECITATION": self = .imageRecitation
    case "IMAGE_OTHER": self = .imageOther
    case "UNEXPECTED_TOOL_CALL": self = .unexpectedToolCall
    case "NO_IMAGE": self = .noImage
    default: self = .unrecognized(rawValue)
    }
  }
}
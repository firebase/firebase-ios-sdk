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

extension GeminiDataModels {
  /// An internal data model for `HarmCategory`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaHarmCategory`
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package enum HarmCategory: Codable, Sendable, Equatable, Hashable {
    /// **PaLM** - Negative or harmful comments targeting identity and/or protected
    /// attribute.
    case derogatory
    
    /// **PaLM** - Content that is rude, disrespectful, or profane.
    case toxicity
    
    /// **PaLM** - Describes scenarios depicting violence against an individual or
    /// group, or general descriptions of gore.
    case violence
    
    /// **PaLM** - Contains references to sexual acts or other lewd content.
    case sexual
    
    /// **PaLM** - Promotes unchecked medical advice.
    case medical
    
    /// **PaLM** - Dangerous content that promotes, facilitates, or encourages
    /// harmful acts.
    case dangerous
    
    /// **Gemini** - Harassment content.
    case harassment
    
    /// **Gemini** - Hate speech and content.
    case hateSpeech
    
    /// **Gemini** - Sexually explicit content.
    case sexuallyExplicit
    
    /// **Gemini** - Dangerous content.
    case dangerousContent
    
    /// **Gemini** - Content that may be used to harm civic integrity.
    /// DEPRECATED: use enable_enhanced_civic_answers instead.
    @available(*, deprecated)
    case civicIntegrity
    
    /// **Gemini** - Prompts attempting to bypass or subvert the model's safety
    /// guidelines (jailbreak attempts).
    case jailbreak
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.HarmCategory: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .derogatory: "HARM_CATEGORY_DEROGATORY"
    case .toxicity: "HARM_CATEGORY_TOXICITY"
    case .violence: "HARM_CATEGORY_VIOLENCE"
    case .sexual: "HARM_CATEGORY_SEXUAL"
    case .medical: "HARM_CATEGORY_MEDICAL"
    case .dangerous: "HARM_CATEGORY_DANGEROUS"
    case .harassment: "HARM_CATEGORY_HARASSMENT"
    case .hateSpeech: "HARM_CATEGORY_HATE_SPEECH"
    case .sexuallyExplicit: "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    case .dangerousContent: "HARM_CATEGORY_DANGEROUS_CONTENT"
    case .civicIntegrity: "HARM_CATEGORY_CIVIC_INTEGRITY"
    case .jailbreak: "HARM_CATEGORY_JAILBREAK"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "HARM_CATEGORY_DEROGATORY": self = .derogatory
    case "HARM_CATEGORY_TOXICITY": self = .toxicity
    case "HARM_CATEGORY_VIOLENCE": self = .violence
    case "HARM_CATEGORY_SEXUAL": self = .sexual
    case "HARM_CATEGORY_MEDICAL": self = .medical
    case "HARM_CATEGORY_DANGEROUS": self = .dangerous
    case "HARM_CATEGORY_HARASSMENT": self = .harassment
    case "HARM_CATEGORY_HATE_SPEECH": self = .hateSpeech
    case "HARM_CATEGORY_SEXUALLY_EXPLICIT": self = .sexuallyExplicit
    case "HARM_CATEGORY_DANGEROUS_CONTENT": self = .dangerousContent
    case "HARM_CATEGORY_CIVIC_INTEGRITY": self = .civicIntegrity
    case "HARM_CATEGORY_JAILBREAK": self = .jailbreak
    default: self = .unrecognized(rawValue)
    }
  }
}
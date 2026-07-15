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
  /// An internal data model for `TranslationConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaTranslationConfig`
  /// 
  /// Config for translation features.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct TranslationConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. If true, the model will generate audio when the target language is spoken,
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. If true, the model will generate audio when the target language is spoken,
    /// essentially it will parrot the input. If false, we will not produce audio
    /// for the target language.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let echoTargetLanguage: Bool?
    
    /// Required. The target language for translation. Supported values are BCP-47 language
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The target language for translation. Supported values are BCP-47 language
    /// codes (e.g. "en", "es", "fr").
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let targetLanguageCode: String
    

    /// Creates a new `TranslationConfig`.
    ///
    /// - Parameters:
    ///   - echoTargetLanguage: Optional. If true, the model will generate audio when the target language is spoken, (Gemini Developer API only). For more details, see ``echoTargetLanguage``.
    ///   - targetLanguageCode: Required. The target language for translation. Supported values are BCP-47 language (Gemini Developer API only). For more details, see ``targetLanguageCode``.
    package init(
      echoTargetLanguage: Bool? = nil,
      targetLanguageCode: String
    ) {
      self.echoTargetLanguage = echoTargetLanguage
      self.targetLanguageCode = targetLanguageCode
    }
    enum CodingKeys: String, CodingKey {
      case echoTargetLanguage = "echoTargetLanguage"
      case targetLanguageCode = "targetLanguageCode"
    }
  }
}
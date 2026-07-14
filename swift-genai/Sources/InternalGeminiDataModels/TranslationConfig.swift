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
  /// Config for translation features.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct TranslationConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. The target language for translation. Supported values are BCP-47 language codes (e.g. "en", "es", "fr").
    /// 
    /// > Important: `targetLanguageCode` is only available in the Gemini Developer API.
    package let targetLanguageCode: String?
    
    /// Optional. If true, the model will generate audio when the target language is spoken, essentially it will parrot the input. If false, we will not produce audio for the target language.
    /// 
    /// > Important: `echoTargetLanguage` is only available in the Gemini Developer API.
    package let echoTargetLanguage: Bool?
    
    /// Creates a new `TranslationConfig`.
    package init(
      targetLanguageCode: String? = nil,
      echoTargetLanguage: Bool? = nil
    ) {
      self.targetLanguageCode = targetLanguageCode
      self.echoTargetLanguage = echoTargetLanguage
    }
    enum CodingKeys: String, CodingKey {
      case targetLanguageCode = "targetLanguageCode"
      case echoTargetLanguage = "echoTargetLanguage"
    }
  }
}
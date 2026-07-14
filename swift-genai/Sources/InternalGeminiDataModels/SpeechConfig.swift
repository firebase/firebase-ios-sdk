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
  /// Config for speech generation and transcription.
  /// 
  /// Variant:
  /// Configuration for speech generation.
  package struct SpeechConfig: Codable, Sendable, Equatable, Hashable {
    /// The configuration in case of single-voice output.
    /// 
    /// Variant:
    /// The configuration for the voice to use.
    package let voiceConfig: VoiceConfig?
    
    /// Optional. The configuration for the multi-speaker setup. It is mutually exclusive with the voice_config field.
    /// 
    /// Variant:
    /// The configuration for a multi-speaker text-to-speech request. This field is mutually exclusive with `voice_config`.
    package let multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig?
    
    /// Optional. The IETF [BCP-47](https://www.rfc-editor.org/rfc/bcp/bcp47.txt) language code that the user configured the app to use. Used for speech recognition and synthesis. Valid values are: `de-DE`, `en-AU`, `en-GB`, `en-IN`, `en-US`, `es-US`, `fr-FR`, `hi-IN`, `pt-BR`, `ar-XA`, `es-ES`, `fr-CA`, `id-ID`, `it-IT`, `ja-JP`, `tr-TR`, `vi-VN`, `bn-IN`, `gu-IN`, `kn-IN`, `ml-IN`, `mr-IN`, `ta-IN`, `te-IN`, `nl-NL`, `ko-KR`, `cmn-CN`, `pl-PL`, `ru-RU`, and `th-TH`.
    /// 
    /// Variant:
    /// Optional. The language code (ISO 639-1) for the speech synthesis.
    package let languageCode: String?
    
    /// Creates a new `SpeechConfig`.
    package init(
      voiceConfig: VoiceConfig? = nil,
      multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig? = nil,
      languageCode: String? = nil
    ) {
      self.voiceConfig = voiceConfig
      self.multiSpeakerVoiceConfig = multiSpeakerVoiceConfig
      self.languageCode = languageCode
    }
    enum CodingKeys: String, CodingKey {
      case voiceConfig = "voiceConfig"
      case multiSpeakerVoiceConfig = "multiSpeakerVoiceConfig"
      case languageCode = "languageCode"
    }
  }
}
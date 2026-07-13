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

extension GoogleAI {
  /// Config for speech generation and transcription.
  package struct SpeechConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The IETF [BCP-47](https://www.rfc-editor.org/rfc/bcp/bcp47.txt) language code that the user configured the app to use. Used for speech recognition and synthesis. Valid values are: `de-DE`, `en-AU`, `en-GB`, `en-IN`, `en-US`, `es-US`, `fr-FR`, `hi-IN`, `pt-BR`, `ar-XA`, `es-ES`, `fr-CA`, `id-ID`, `it-IT`, `ja-JP`, `tr-TR`, `vi-VN`, `bn-IN`, `gu-IN`, `kn-IN`, `ml-IN`, `mr-IN`, `ta-IN`, `te-IN`, `nl-NL`, `ko-KR`, `cmn-CN`, `pl-PL`, `ru-RU`, and `th-TH`.
    package var languageCode: String?
    
    /// Optional. The configuration for the multi-speaker setup. It is mutually exclusive with the voice_config field.
    package var multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig?
    
    /// The configuration in case of single-voice output.
    package var voiceConfig: VoiceConfig?
    
    /// Creates a new `SpeechConfig`.
    package init(
      languageCode: String? = nil,
      multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig? = nil,
      voiceConfig: VoiceConfig? = nil
    ) {
      self.languageCode = languageCode
      self.multiSpeakerVoiceConfig = multiSpeakerVoiceConfig
      self.voiceConfig = voiceConfig
    }
    enum CodingKeys: String, CodingKey {
      case languageCode = "languageCode"
      case multiSpeakerVoiceConfig = "multiSpeakerVoiceConfig"
      case voiceConfig = "voiceConfig"
    }
  }
}
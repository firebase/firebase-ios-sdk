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


extension AgentPlatform {
  /// Configuration for speech generation.
  public struct SpeechConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The language code (ISO 639-1) for the speech synthesis.
    public var languageCode: String?
    
    /// The configuration for a multi-speaker text-to-speech request. This field is mutually exclusive with `voice_config`.
    public var multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig?
    
    /// The configuration for the voice to use.
    public var voiceConfig: VoiceConfig?
    
    /// Creates a new `SpeechConfig`.
    public init(
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
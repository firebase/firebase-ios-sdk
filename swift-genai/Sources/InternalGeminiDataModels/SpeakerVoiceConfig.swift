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
  /// An internal data model for `SpeakerVoiceConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaSpeakerVoiceConfig`
  /// 
  /// The configuration for a single speaker in a multi speaker setup.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1SpeakerVoiceConfig`
  /// 
  /// Configuration for a single speaker in a multi-speaker setup.
  package struct SpeakerVoiceConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. The name of the speaker to use. Should be the same as in the prompt.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The name of the speaker to use. Should be the same as in the prompt.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The name of the speaker. This should be the same as the speaker
    /// name used in the prompt.
    package let speaker: String
    
    /// Required. The configuration for the voice to use.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The configuration for the voice to use.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The configuration for the voice of this speaker.
    package let voiceConfig: VoiceConfig
    

    /// Creates a new `SpeakerVoiceConfig`.
    ///
    /// - Parameters:
    ///   - speaker: Required. The name of the speaker to use. Should be the same as in the prompt. (behavior varies by backend). For more details, see ``speaker``.
    ///   - voiceConfig: Required. The configuration for the voice to use. (behavior varies by backend). For more details, see ``voiceConfig``.
    package init(
      speaker: String,
      voiceConfig: VoiceConfig
    ) {
      self.speaker = speaker
      self.voiceConfig = voiceConfig
    }
    enum CodingKeys: String, CodingKey {
      case speaker = "speaker"
      case voiceConfig = "voiceConfig"
    }
  }
}
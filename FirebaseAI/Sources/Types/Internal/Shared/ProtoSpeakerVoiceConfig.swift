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

struct ProtoSpeakerVoiceConfig: Sendable, Equatable {
  let speaker: String
  let voiceConfig: ProtoVoiceConfig

  init(speaker: String, voiceConfig: ProtoVoiceConfig) {
    self.speaker = speaker
    self.voiceConfig = voiceConfig
  }
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension ProtoSpeakerVoiceConfig {
  func toGoogleAI() -> GoogleAI.SpeakerVoiceConfig {
    GoogleAI.SpeakerVoiceConfig(
      speaker: speaker,
      voiceConfig: voiceConfig.toGoogleAI()
    )
  }

  func toAgentPlatform() -> AgentPlatform.SpeakerVoiceConfig {
    AgentPlatform.SpeakerVoiceConfig(
      speaker: speaker,
      voiceConfig: voiceConfig.toAgentPlatform()
    )
  }

  init?(fromGoogleAI config: GoogleAI.SpeakerVoiceConfig) {
    guard let speaker = config.speaker, let voice = config.voiceConfig, let voiceConfig = ProtoVoiceConfig(fromGoogleAI: voice) else { return nil }
    self.speaker = speaker
    self.voiceConfig = voiceConfig
  }

  init?(fromAgentPlatform config: AgentPlatform.SpeakerVoiceConfig) {
    guard let speaker = config.speaker, let voice = config.voiceConfig, let voiceConfig = ProtoVoiceConfig(fromAgentPlatform: voice) else { return nil }
    self.speaker = speaker
    self.voiceConfig = voiceConfig
  }
}

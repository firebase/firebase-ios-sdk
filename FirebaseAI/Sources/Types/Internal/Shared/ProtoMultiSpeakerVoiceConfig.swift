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

struct ProtoMultiSpeakerVoiceConfig: Sendable, Equatable {
  let speakerVoiceConfigs: [ProtoSpeakerVoiceConfig]

  init(speakerVoiceConfigs: [ProtoSpeakerVoiceConfig]) {
    self.speakerVoiceConfigs = speakerVoiceConfigs
  }
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension ProtoMultiSpeakerVoiceConfig {
  func toGoogleAI() -> GoogleAI.MultiSpeakerVoiceConfig {
    GoogleAI.MultiSpeakerVoiceConfig(
      speakerVoiceConfigs: speakerVoiceConfigs.map { $0.toGoogleAI() }
    )
  }

  func toAgentPlatform() -> AgentPlatform.MultiSpeakerVoiceConfig {
    AgentPlatform.MultiSpeakerVoiceConfig(
      speakerVoiceConfigs: speakerVoiceConfigs.map { $0.toAgentPlatform() }
    )
  }

  init(fromGoogleAI config: GoogleAI.MultiSpeakerVoiceConfig) {
    self.speakerVoiceConfigs = config.speakerVoiceConfigs?.compactMap { ProtoSpeakerVoiceConfig(fromGoogleAI: $0) } ?? []
  }

  init(fromAgentPlatform config: AgentPlatform.MultiSpeakerVoiceConfig) {
    self.speakerVoiceConfigs = config.speakerVoiceConfigs?.compactMap { ProtoSpeakerVoiceConfig(fromAgentPlatform: $0) } ?? []
  }
}

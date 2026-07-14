// Copyright 2025 Google LLC
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

/// Configuration for the speaker to use.
enum ProtoVoiceConfig: Sendable, Equatable {
  /// Configuration for the prebuilt voice to use.
  case prebuiltVoiceConfig(ProtoPrebuiltVoiceConfig)

  /// Configuration for the custom voice to use.
  case customVoiceConfig(ProtoCustomVoiceConfig)
}

/// The configuration for the prebuilt speaker to use.
///
/// Not just a string on the parent proto, because there'll likely be a lot
/// more options here.
struct ProtoPrebuiltVoiceConfig: Sendable, Equatable {
  /// The name of the preset voice to use.
  let voiceName: String

  init(voiceName: String) {
    self.voiceName = voiceName
  }
}

/// The configuration for the custom voice to use.
struct ProtoCustomVoiceConfig: Sendable, Equatable {
  /// The sample of the custom voice, in pcm16 s16e format.
  let customVoiceSample: Data

  init(customVoiceSample: Data) {
    self.customVoiceSample = customVoiceSample
  }
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension ProtoVoiceConfig {
  func toGoogleAI() -> GoogleAI.VoiceConfig {
    switch self {
    case let .prebuiltVoiceConfig(setup):
      return GoogleAI.VoiceConfig(prebuiltVoiceConfig: GoogleAI.PrebuiltVoiceConfig(voiceName: setup.voiceName))
    case .customVoiceConfig:
      return GoogleAI.VoiceConfig()
    }
  }

  func toAgentPlatform() -> AgentPlatform.VoiceConfig {
    switch self {
    case let .prebuiltVoiceConfig(setup):
      return AgentPlatform.VoiceConfig(prebuiltVoiceConfig: AgentPlatform.PrebuiltVoiceConfig(voiceName: setup.voiceName))
    case .customVoiceConfig:
      return AgentPlatform.VoiceConfig()
    }
  }

  init?(fromGoogleAI config: GoogleAI.VoiceConfig) {
    if let prebuilt = config.prebuiltVoiceConfig, let name = prebuilt.voiceName {
      self = .prebuiltVoiceConfig(ProtoPrebuiltVoiceConfig(voiceName: name))
    } else {
      return nil
    }
  }

  init?(fromAgentPlatform config: AgentPlatform.VoiceConfig) {
    if let prebuilt = config.prebuiltVoiceConfig, let name = prebuilt.voiceName {
      self = .prebuiltVoiceConfig(ProtoPrebuiltVoiceConfig(voiceName: name))
    } else {
      return nil
    }
  }
}

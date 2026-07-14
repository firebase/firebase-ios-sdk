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

/// Speech configuration class for controlling the model's speech and audio generation behaviors.
///
/// This allows you to configure the voice properties (single-speaker OR multi-speaker setup) and
/// language preferences when requesting the model to generate spoken responses.
public struct SpeechConfig: Sendable {
  let speechConfig: ProtoSpeechConfig

  init(_ speechConfig: ProtoSpeechConfig) {
    self.speechConfig = speechConfig
  }

  /// Creates a new ``SpeechConfig`` value for a single voice.
  ///
  /// - Parameters:
  ///   - voiceName: The name of the prebuilt voice to be used for the model's speech response.
  ///
  ///     To learn more about the available voices, see the docs on
  ///     [Voice options](https://ai.google.dev/gemini-api/docs/speech-generation#voices)\.
  ///   - languageCode: BCP-47 language code to use when parsing text sent from the client, instead
  ///     of audio. By default, the model will attempt to detect the input language automatically.
  ///
  ///     To learn which codes are supported, see the docs on
  ///     [Supported languages](https://ai.google.dev/gemini-api/docs/speech-generation#languages)\.
  public init(voiceName: String, languageCode: String? = nil) {
    self.init(
      ProtoSpeechConfig(
        voiceConfig: .prebuiltVoiceConfig(.init(voiceName: voiceName)),
        languageCode: languageCode
      )
    )
  }

  /// Creates a new ``SpeechConfig`` value for a multi-speaker setup.
  ///
  /// > Warning: Multi-speaker configurations are not currently supported by the Live API (e.g.,
  /// > `LiveGenerationConfig`).
  ///
  /// - Parameters:
  ///   - multiSpeakerVoiceConfig: The configuration detailing multiple speakers and their
  ///     corresponding voices.
  ///   - languageCode: BCP-47 language code to use when parsing text sent from the client.
  public init(multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig, languageCode: String? = nil) {
    self.init(
      ProtoSpeechConfig(
        multiSpeakerVoiceConfig: multiSpeakerVoiceConfig.multiSpeakerVoiceConfig,
        languageCode: languageCode
      )
    )
  }
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension SpeechConfig {
  package func toGoogleAI() -> GoogleAI.SpeechConfig {
    speechConfig.toGoogleAI()
  }

  package func toAgentPlatform() -> AgentPlatform.SpeechConfig {
    speechConfig.toAgentPlatform()
  }

  package init(fromGoogleAI config: GoogleAI.SpeechConfig) {
    self.init(ProtoSpeechConfig(fromGoogleAI: config))
  }

  package init(fromAgentPlatform config: AgentPlatform.SpeechConfig) {
    self.init(ProtoSpeechConfig(fromAgentPlatform: config))
  }
}

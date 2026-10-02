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

/// **[Public Preview]** Configuration for model speech and audio generation behaviors.
///
/// > Warning: This API is a public preview and may be subject to change.
///
/// Configures voice properties (single-speaker or multi-speaker setup) and language preferences
/// when requesting the model to generate spoken responses.
///
/// For turn-level speech delivery control (such as emotion, pacing, and whispering), attach
/// ``SpeechMetadata`` to individual ``TextPart`` instances in your request prompt.
///
/// For more details on speech generation, see the
/// [Text-to-speech guide](https://firebase.google.com/docs/ai-logic/generate-speech).
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
  ///     For available voices, see the documentation on
  ///     [voices](https://firebase.google.com/docs/ai-logic/generate-speech#response-voices).
  ///   - languageCode: BCP-47 language code to use when parsing text sent from the client, instead
  ///     of audio. By default, the model will attempt to detect the input language automatically.
  ///
  ///     For supported language codes, see the documentation on
  ///     [languages](https://firebase.google.com/docs/ai-logic/generate-speech#languages).
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
  /// > Warning: Multi-speaker configurations are not currently supported by the Live API, such as
  /// > ``LiveGenerationConfig``.
  ///
  /// - Parameters:
  ///   - multiSpeakerVoiceConfig: The configuration detailing multiple speakers and their
  ///     corresponding voices.
  ///
  ///     > Important: When using a multi-speaker configuration, each dialogue turn in the
  ///     > request prompt must be passed as a separate ``TextPart`` with ``SpeechMetadata``
  ///     > specifying a `speaker` matching one of the configured speakers. `speaker` is required
  ///     > on every part in a multi-speaker request.
  ///
  ///     See the documentation on
  ///     [multi-speaker](https://firebase.google.com/docs/ai-logic/generate-speech#multi-speaker)
  ///     for more details.
  ///   - languageCode: BCP-47 language code to use when parsing text sent from the client.
  ///
  ///     For supported language codes, see the documentation on
  ///     [languages](https://firebase.google.com/docs/ai-logic/generate-speech#languages).
  public init(multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig, languageCode: String? = nil) {
    self.init(
      ProtoSpeechConfig(
        multiSpeakerVoiceConfig: multiSpeakerVoiceConfig.multiSpeakerVoiceConfig,
        languageCode: languageCode
      )
    )
  }
}

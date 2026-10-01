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

/// **[Public Preview]** Configuration pairing a speaker name or identifier with a preset voice.
///
/// > Warning: This API is a public preview and may be subject to change.
///
/// This configuration pairs a speaker name (such as `"Alice"` or `"Joe"`) with a preset voice name.
/// The `speaker` name defined here must match the `speaker` string specified in ``SpeechMetadata``
/// on each dialogue turn's ``TextPart`` in a multi-speaker request.
public struct SpeakerVoiceConfig: Sendable {
  let speakerVoiceConfig: ProtoSpeakerVoiceConfig

  init(_ speakerVoiceConfig: ProtoSpeakerVoiceConfig) {
    self.speakerVoiceConfig = speakerVoiceConfig
  }

  /// Creates a configuration for a speaker using a voice name.
  ///
  /// - Parameters:
  ///   - speaker: The unique name or identifier of the speaker (for example, `"Alice"`). This name
  ///     must be passed to ``SpeechMetadata/init(speaker:style:)`` for this speaker's turns.
  ///   - voiceName: The name of the preset voice to assign to this speaker.
  ///
  ///     For a list of available voices, see the documentation on
  ///     [voices](https://firebase.google.com/docs/ai-logic/generate-speech#response-voices).
  public init(speaker: String, voiceName: String) {
    self.init(
      ProtoSpeakerVoiceConfig(
        speaker: speaker,
        voiceConfig: .prebuiltVoiceConfig(ProtoPrebuiltVoiceConfig(voiceName: voiceName))
      )
    )
  }
}

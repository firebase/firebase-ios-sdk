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

/// Configures a participating speaker within a multi-speaker setup.
///
/// When generating multi-speaker conversational audio, each speaker must be configured with a
/// unique
/// name and a specific voice. Find the list of
/// [supported voices](https://cloud.google.com/text-to-speech/docs/chirp3-hd).
public struct SpeakerVoiceConfig: Sendable {
  let speakerVoiceConfig: ProtoSpeakerVoiceConfig

  init(_ speakerVoiceConfig: ProtoSpeakerVoiceConfig) {
    self.speakerVoiceConfig = speakerVoiceConfig
  }

  /// Creates a configuration for a speaker using a voice name.
  ///
  /// - Parameters:
  ///   - speaker: The unique name/identifier of the speaker (e.g., `"Alice"`).
  ///   - voiceName: The name of the preset voice to assign to this speaker.
  public init(speaker: String, voiceName: String) {
    self.init(
      ProtoSpeakerVoiceConfig(
        speaker: speaker,
        voiceConfig: .prebuiltVoiceConfig(ProtoPrebuiltVoiceConfig(voiceName: voiceName))
      )
    )
  }
}

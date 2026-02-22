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

/// The configuration for a single speaker in a multi speaker setup.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct SpeakerVoiceConfig: Encodable, Sendable {
  /// The name of the speaker to use. Should be the same as in the prompt.
  public let speaker: String

  /// The configuration for the voice to use.
  let voiceConfig: VoiceConfig

  /// Creates a configuration using a prebuilt voice.
  public init(speaker: String, prebuiltVoiceConfig: PrebuiltVoiceConfig) {
    self.speaker = speaker
    voiceConfig = .prebuiltVoiceConfig(prebuiltVoiceConfig)
  }
}

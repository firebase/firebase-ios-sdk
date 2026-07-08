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

/// Configuration for a multi-speaker audio generation setup.
///
/// Enables the model to generate audio containing multiple distinct speakers, alternating voices
/// dynamically based on speaker labels in the prompt.
///
/// > Warning: Multi-speaker configurations are not currently supported by the Live API (e.g.,
/// > `LiveGenerationConfig`).
public struct MultiSpeakerVoiceConfig: Sendable {
  let multiSpeakerVoiceConfig: ProtoMultiSpeakerVoiceConfig

  init(_ multiSpeakerVoiceConfig: ProtoMultiSpeakerVoiceConfig) {
    self.multiSpeakerVoiceConfig = multiSpeakerVoiceConfig
  }

  /// Creates a configuration for the multi-speaker setup.
  ///
  /// - Parameters:
  ///   - speakerVoiceConfigs: A list of voice configurations for the participating speakers.
  ///     Currently, the backend requires exactly **two** speaker voice configurations.
  public init(speakerVoiceConfigs: [SpeakerVoiceConfig]) {
    self.init(
      ProtoMultiSpeakerVoiceConfig(
        speakerVoiceConfigs: speakerVoiceConfigs.map(\.speakerVoiceConfig)
      )
    )
  }
}

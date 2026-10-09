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

/// Configuration for speech generation.
package struct SpeechConfig: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The language code (ISO 639-1) for the speech synthesis.
  package var languageCode: String?

  /// The configuration for a multi-speaker text-to-speech request. This field is mutually exclusive
  /// with `voice_config`.
  package var multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig?

  /// The configuration for the voice to use.
  package var voiceConfig: VoiceConfig?

  /// Initializes a new `SpeechConfig`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case languageCode
    case multiSpeakerVoiceConfig
    case voiceConfig
  }
}

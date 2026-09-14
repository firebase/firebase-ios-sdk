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

/// The configuration for speech interaction.
package struct SpeechConfig: Codable, Sendable, Equatable, Hashable {

  /// The language of the speech.
  package let language: String?

  /// The speaker's name, it should match the speaker name given in the prompt.
  package let speaker: String?

  /// The voice of the speaker.
  package let voice: String?

  /// Creates a new `SpeechConfig`.
  ///
  /// - Parameters:
  ///   - language: The language of the speech.
  ///   - speaker: The speaker's name, it should match the speaker name given in the prompt.
  ///   - voice: The voice of the speaker.
  package init(
    language: String? = nil,
    speaker: String? = nil,
    voice: String? = nil
  ) {
    self.language = language
    self.speaker = speaker
    self.voice = voice
  }
  enum CodingKeys: String, CodingKey {
    case language = "language"
    case speaker = "speaker"
    case voice = "voice"
  }
}

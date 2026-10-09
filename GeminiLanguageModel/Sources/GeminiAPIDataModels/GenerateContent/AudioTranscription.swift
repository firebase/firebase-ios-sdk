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

/// The transcription of an audio part. For multi-speaker audio, each speaker segment is a separate
/// `Part` with its own `AudioTranscription` carrying the `speaker_label`.
package struct AudioTranscription: Codable, Sendable, Equatable, Hashable, Buildable {
  /// A label identifying the speaker of this audio segment (e.g. `spk_1`, `spk_2`). Present when
  /// `diarization` is set.
  package var speakerLabel: String?

  /// Required. The transcription text of this audio segment.
  package var text: String?

  /// Detailed word-level transcriptions and timing details. Present when `word_timestamp` is set.
  package var words: [AudioTranscriptionWordInfo]?

  /// Initializes a new `AudioTranscription`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case speakerLabel
    case text
    case words
  }
}

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

/// Word-level ASR annotation for transcription output.
/// Carries the word text, optional timing, and optional speaker attribution.
package struct WordInfo: Codable, Sendable, Equatable, Hashable {

  /// End of the attributed segment, exclusive.
  package let endIndex: Int?

  /// End offset in time of the word relative to the start of the audio.
  /// Present when timestamp_granularities contains "word".
  package let endOffset: String?

  /// Optional. Speaker label for this word (e.g. "spk_1", "spk_2").
  /// Present when diarization_mode is set in TranscriptionConfig.
  package let speaker: String?

  /// Start of segment of the response that is attributed to this source.
  ///
  /// Index indicates the start of the segment, measured in bytes.
  package let startIndex: Int?

  /// Start offset in time of the word relative to the start of the audio.
  /// Present when timestamp_granularities contains "word".
  package let startOffset: String?

  /// The transcribed word.
  package let text: String?

  package let type: String?

  /// Creates a new `WordInfo`.
  ///
  /// - Parameters:
  ///   - endIndex: End of the attributed segment, exclusive.
  ///   - endOffset: End offset in time of the word relative to the start of the audio.
  ///   - speaker: Optional. Speaker label for this word (e.g. "spk_1", "spk_2").
  ///   - startIndex: Start of segment of the response that is attributed to this source.
  ///   - startOffset: Start offset in time of the word relative to the start of the audio.
  ///   - text: The transcribed word.
  package init(
    endIndex: Int? = nil,
    endOffset: String? = nil,
    speaker: String? = nil,
    startIndex: Int? = nil,
    startOffset: String? = nil,
    text: String? = nil
  ) {
    self.endIndex = endIndex
    self.endOffset = endOffset
    self.speaker = speaker
    self.startIndex = startIndex
    self.startOffset = startOffset
    self.text = text
    self.type = "word_info"
  }
  enum CodingKeys: String, CodingKey {
    case endIndex = "end_index"
    case endOffset = "end_offset"
    case speaker = "speaker"
    case startIndex = "start_index"
    case startOffset = "start_offset"
    case text = "text"
    case type = "type"
  }
}

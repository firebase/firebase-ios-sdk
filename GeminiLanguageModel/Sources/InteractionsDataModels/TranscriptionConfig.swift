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

package import GeminiSharedDataModels

/// Configuration for speech recognition (transcription).
package struct TranscriptionConfig: Codable, Sendable, Equatable, Hashable {

  /// Optional. A list of phrases to bias the ASR model towards.
  @available(*, deprecated)
  package let adaptationPhrases: [String]?

  /// Optional. A list of custom vocabulary phrases to bias the speech recognition model
  /// toward recognizing specific terms.
  package let customVocabulary: [String]?

  /// Optional. Configures speaker diarization. Supported values: "speaker".
  @available(*, deprecated)
  package let diarizationMode: String?

  /// Optional. BCP-47 language codes providing hints about the languages present in the
  /// audio. If omitted or empty, defaults to automatic language detection.
  package let languageCodes: [String]?

  /// Discriminated transcription mode options or enum.
  package let mode: JSONValue?

  /// Optional. The granularity of timestamps to include in the transcription output.
  /// Supported values: "word". If empty, no timestamps are generated.
  @available(*, deprecated)
  package let timestampGranularities: [String]?

  /// Creates a new `TranscriptionConfig`.
  ///
  /// - Parameters:
  ///   - adaptationPhrases: Optional. A list of phrases to bias the ASR model towards.
  ///   - customVocabulary: Optional. A list of custom vocabulary phrases to bias the speech recognition model
  ///   - diarizationMode: Optional. Configures speaker diarization. Supported values: "speaker".
  ///   - languageCodes: Optional. BCP-47 language codes providing hints about the languages present in the
  ///   - mode: Discriminated transcription mode options or enum.
  ///   - timestampGranularities: Optional. The granularity of timestamps to include in the transcription output.
  package init(
    adaptationPhrases: [String]? = nil,
    customVocabulary: [String]? = nil,
    diarizationMode: String? = nil,
    languageCodes: [String]? = nil,
    mode: JSONValue? = nil,
    timestampGranularities: [String]? = nil
  ) {
    self.adaptationPhrases = adaptationPhrases
    self.customVocabulary = customVocabulary
    self.diarizationMode = diarizationMode
    self.languageCodes = languageCodes
    self.mode = mode
    self.timestampGranularities = timestampGranularities
  }
  enum CodingKeys: String, CodingKey {
    case adaptationPhrases = "adaptation_phrases"
    case customVocabulary = "custom_vocabulary"
    case diarizationMode = "diarization_mode"
    case languageCodes = "language_codes"
    case mode = "mode"
    case timestampGranularities = "timestamp_granularities"
  }
}

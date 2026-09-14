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

/// Configuration for verbatim transcription mode.
package struct VerbatimTranscriptionMode: Codable, Sendable, Equatable, Hashable {

  /// Optional. Configures speaker diarization. Supported values: "speaker".
  package let diarizationMode: String?

  /// Optional. The granularity of timestamps to include in the transcription output.
  /// Supported values: "word". If empty, no timestamps are generated.
  package let timestampGranularities: [String]?

  package let type: String?

  /// Creates a new `VerbatimTranscriptionMode`.
  ///
  /// - Parameters:
  ///   - diarizationMode: Optional. Configures speaker diarization. Supported values: "speaker".
  ///   - timestampGranularities: Optional. The granularity of timestamps to include in the transcription output.
  package init(
    diarizationMode: String? = nil,
    timestampGranularities: [String]? = nil
  ) {
    self.diarizationMode = diarizationMode
    self.timestampGranularities = timestampGranularities
    self.type = "verbatim"
  }
  enum CodingKeys: String, CodingKey {
    case diarizationMode = "diarization_mode"
    case timestampGranularities = "timestamp_granularities"
    case type = "type"
  }
}

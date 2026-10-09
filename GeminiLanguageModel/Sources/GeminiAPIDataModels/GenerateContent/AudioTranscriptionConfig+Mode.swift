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

extension AudioTranscriptionConfig {
  /// Configures transcription mode. Supported values: `VERBATIM`, `SMART`. If unspecified, defaults
  /// to `VERBATIM` transcription. In `SMART` mode, the model performs disfluency removal
  /// (eliminating filler words, repetitions, and false starts), light grammatical cleanup,
  /// automatic formatting (paragraphs, bullet points, numbered lists), and minor user edits (inline
  /// self-corrections). Timestamps and diarization are incompatible with mode `SMART`.
  package enum Mode: Codable, Sendable, Equatable, Hashable {
    /// Verbatim transcription mode.
    case verbatim

    /// Smart transcription mode.
    case smart

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AudioTranscriptionConfig.Mode: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .verbatim: "VERBATIM"
    case .smart: "SMART"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "VERBATIM": self = .verbatim
    case "SMART": self = .smart
    default: self = .unrecognized(rawValue)
    }
  }
}

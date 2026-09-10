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

extension AudioResponseFormat {
  /// The MIME type of the audio output.
  package enum MimeType: Codable, Sendable, Equatable, Hashable {

    /// MP3 audio format.
    case mp3

    /// OGG Opus audio format.
    case oggOpus

    /// Raw PCM (L16) audio format.
    case l16

    /// WAV audio format.
    case wav

    /// A-law audio format.
    case alaw

    /// Mu-law audio format.
    case mulaw

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AudioResponseFormat.MimeType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .mp3: "audio/mp3"
    case .oggOpus: "audio/ogg_opus"
    case .l16: "audio/l16"
    case .wav: "audio/wav"
    case .alaw: "audio/alaw"
    case .mulaw: "audio/mulaw"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "audio/mp3": self = .mp3
    case "audio/ogg_opus": self = .oggOpus
    case "audio/l16": self = .l16
    case "audio/wav": self = .wav
    case "audio/alaw": self = .alaw
    case "audio/mulaw": self = .mulaw
    default: self = .unrecognized(rawValue)
    }
  }
}

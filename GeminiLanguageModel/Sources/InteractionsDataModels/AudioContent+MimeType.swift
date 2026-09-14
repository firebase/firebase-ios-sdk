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

extension AudioContent {
  /// The mime type of the audio.
  package enum MimeType: Codable, Sendable, Equatable, Hashable {

    /// WAV audio format
    case wav

    /// MP3 audio format
    case mp3

    /// AIFF audio format
    case aiff

    /// AAC audio format
    case aac

    /// OGG audio format
    case ogg

    /// FLAC audio format
    case flac

    /// MPEG audio format
    case mpeg

    /// M4A audio format
    case m4a

    /// L16 audio format
    case l16

    /// OPUS audio format
    case opus

    /// ALAW audio format
    case alaw

    /// MULAW audio format
    case mulaw

    /// WEBM audio format
    case webm

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AudioContent.MimeType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .wav: "audio/wav"
    case .mp3: "audio/mp3"
    case .aiff: "audio/aiff"
    case .aac: "audio/aac"
    case .ogg: "audio/ogg"
    case .flac: "audio/flac"
    case .mpeg: "audio/mpeg"
    case .m4a: "audio/m4a"
    case .l16: "audio/l16"
    case .opus: "audio/opus"
    case .alaw: "audio/alaw"
    case .mulaw: "audio/mulaw"
    case .webm: "audio/webm"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "audio/wav": self = .wav
    case "audio/mp3": self = .mp3
    case "audio/aiff": self = .aiff
    case "audio/aac": self = .aac
    case "audio/ogg": self = .ogg
    case "audio/flac": self = .flac
    case "audio/mpeg": self = .mpeg
    case "audio/m4a": self = .m4a
    case "audio/l16": self = .l16
    case "audio/opus": self = .opus
    case "audio/alaw": self = .alaw
    case "audio/mulaw": self = .mulaw
    case "audio/webm": self = .webm
    default: self = .unrecognized(rawValue)
    }
  }
}

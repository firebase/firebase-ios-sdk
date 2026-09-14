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

/// An internal data model for `ResponseModality`.
package enum ResponseModality: Codable, Sendable, Equatable, Hashable {

  /// Indicates the model should return text.
  case text

  /// Indicates the model should return images.
  case image

  /// Indicates the model should return audio.
  case audio

  /// Indicates the model should return video.
  case video

  /// Indicates the model should return documents.
  case document

  /// Unrecognized case.
  ///
  /// - Parameter value: The raw string value of the unrecognized enum case.
  case unrecognized(_ value: String)
}

// MARK: - RawRepresentable Conformance

extension ResponseModality: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .text: "text"
    case .image: "image"
    case .audio: "audio"
    case .video: "video"
    case .document: "document"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "text": self = .text
    case "image": self = .image
    case "audio": self = .audio
    case "video": self = .video
    case "document": self = .document
    default: self = .unrecognized(rawValue)
    }
  }
}

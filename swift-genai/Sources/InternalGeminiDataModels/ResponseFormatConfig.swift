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

extension GeminiDataModels {
  /// Configuration for the response output format.
  /// Handles single object serialization for Gemini Developer API and array-wrapped serialization for Gemini Enterprise Agent Platform (Vertex AI).
  package struct ResponseFormatConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Text output format configuration.
    package var text: TextResponseFormat?

    /// Optional. Audio output format configuration.
    package var audio: AudioResponseFormat?

    /// Optional. Image output format configuration.
    package var image: ImageResponseFormat?

    /// Optional. Video output format configuration.
    package var video: VideoResponseFormat?

    /// Creates a new `ResponseFormatConfig`.
    package init(
      text: TextResponseFormat? = nil,
      audio: AudioResponseFormat? = nil,
      image: ImageResponseFormat? = nil,
      video: VideoResponseFormat? = nil
    ) {
      self.text = text
      self.audio = audio
      self.image = image
      self.video = video
    }

    package init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let array = try? container.decode([ResponseFormatConfig].self), let first = array.first {
        self.text = first.text
        self.audio = first.audio
        self.image = first.image
        self.video = first.video
      } else {
        let objectContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try objectContainer.decodeIfPresent(TextResponseFormat.self, forKey: .text)
        self.audio = try objectContainer.decodeIfPresent(AudioResponseFormat.self, forKey: .audio)
        self.image = try objectContainer.decodeIfPresent(ImageResponseFormat.self, forKey: .image)
        self.video = try objectContainer.decodeIfPresent(VideoResponseFormat.self, forKey: .video)
      }
    }

    package func encode(to encoder: Encoder) throws {
      if let useArrayFormat = encoder.userInfo[ResponseFormatConfig.useArrayFormatKey] as? Bool, useArrayFormat {
        var container = encoder.unkeyedContainer()
        let helper = EncodingHelper(text: text, audio: audio, image: image, video: video)
        try container.encode(helper)
      } else {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(audio, forKey: .audio)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(video, forKey: .video)
      }
    }

    private enum CodingKeys: String, CodingKey {
      case text
      case audio
      case image
      case video
    }

    private struct EncodingHelper: Encodable {
      let text: TextResponseFormat?
      let audio: AudioResponseFormat?
      let image: ImageResponseFormat?
      let video: VideoResponseFormat?

      enum CodingKeys: String, CodingKey {
        case text
        case audio
        case image
        case video
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(audio, forKey: .audio)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(video, forKey: .video)
      }
    }

    /// Key to put in encoder.userInfo to control whether to encode this type as an array of objects
    /// (Gemini Enterprise Agent Platform / Vertex AI) or as a single flat object (Gemini Developer API).
    package static let useArrayFormatKey = CodingUserInfoKey(rawValue: "useArrayFormatKey")!
  }
}
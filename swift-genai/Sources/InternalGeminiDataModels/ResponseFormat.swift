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
  /// Configuration for the model to configure output formatting and delivery.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct ResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Text output format.
    /// 
    /// > Important: `text` is only available in the Gemini Enterprise Agent Platform.
    package let text: TextResponseFormat?
    
    /// Video output format.
    /// 
    /// > Important: `video` is only available in the Gemini Enterprise Agent Platform.
    package let video: VideoResponseFormat?
    
    /// Audio output format.
    /// 
    /// > Important: `audio` is only available in the Gemini Enterprise Agent Platform.
    package let audio: AudioResponseFormat?
    
    /// Image output format.
    /// 
    /// > Important: `image` is only available in the Gemini Enterprise Agent Platform.
    package let image: ImageResponseFormat?
    
    /// Creates a new `ResponseFormat`.
    package init(
      text: TextResponseFormat? = nil,
      video: VideoResponseFormat? = nil,
      audio: AudioResponseFormat? = nil,
      image: ImageResponseFormat? = nil
    ) {
      self.text = text
      self.video = video
      self.audio = audio
      self.image = image
    }
    enum CodingKeys: String, CodingKey {
      case text = "text"
      case video = "video"
      case audio = "audio"
      case image = "image"
    }
  }
}
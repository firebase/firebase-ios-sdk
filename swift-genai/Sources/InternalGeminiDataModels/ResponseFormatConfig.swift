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
  /// Configuration for the response output format. This is a flat object where each optional sub-field configures a specific output modality.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct ResponseFormatConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Text output format configuration.
    /// 
    /// > Important: `text` is only available in the Gemini Developer API.
    package let text: TextResponseFormat?
    
    /// Optional. Audio output format configuration.
    /// 
    /// > Important: `audio` is only available in the Gemini Developer API.
    package let audio: AudioResponseFormat?
    
    /// Optional. Image output format configuration.
    /// 
    /// > Important: `image` is only available in the Gemini Developer API.
    package let image: ImageResponseFormat?
    
    /// Creates a new `ResponseFormatConfig`.
    package init(
      text: TextResponseFormat? = nil,
      audio: AudioResponseFormat? = nil,
      image: ImageResponseFormat? = nil
    ) {
      self.text = text
      self.audio = audio
      self.image = image
    }
    enum CodingKeys: String, CodingKey {
      case text = "text"
      case audio = "audio"
      case image = "image"
    }
  }
}
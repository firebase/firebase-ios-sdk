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


extension GoogleAI {
  /// Configuration for the response output format. This is a flat object where each optional sub-field configures a specific output modality.
  public struct ResponseFormatConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Audio output format configuration.
    public var audio: AudioResponseFormat?
    
    /// Optional. Image output format configuration.
    public var image: ImageResponseFormat?
    
    /// Optional. Text output format configuration.
    public var text: TextResponseFormat?
    
    /// Creates a new `ResponseFormatConfig`.
    public init(
      audio: AudioResponseFormat? = nil,
      image: ImageResponseFormat? = nil,
      text: TextResponseFormat? = nil
    ) {
      self.audio = audio
      self.image = image
      self.text = text
    }
    enum CodingKeys: String, CodingKey {
      case audio = "audio"
      case image = "image"
      case text = "text"
    }
  }
}
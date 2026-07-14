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


extension AgentPlatform {
  /// Configuration for the model to configure output formatting and delivery.
  public struct ResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Audio output format.
    public var audio: AudioResponseFormat?
    
    /// Image output format.
    public var image: ImageResponseFormat?
    
    /// Text output format.
    public var text: TextResponseFormat?
    
    /// Video output format.
    public var video: VideoResponseFormat?
    
    /// Creates a new `ResponseFormat`.
    public init(
      audio: AudioResponseFormat? = nil,
      image: ImageResponseFormat? = nil,
      text: TextResponseFormat? = nil,
      video: VideoResponseFormat? = nil
    ) {
      self.audio = audio
      self.image = image
      self.text = text
      self.video = video
    }
    enum CodingKeys: String, CodingKey {
      case audio = "audio"
      case image = "image"
      case text = "text"
      case video = "video"
    }
  }
}
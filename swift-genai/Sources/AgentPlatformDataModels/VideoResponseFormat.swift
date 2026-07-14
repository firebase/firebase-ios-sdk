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
  /// Configuration for video-specific output formatting.
  public struct VideoResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// The aspect ratio for the video output.
    public var aspectRatio: AspectRatio?
    
    /// Optional. Delivery mode for the generated content.
    public var delivery: Delivery?
    
    /// Optional. The duration for the video output.
    public var duration: Duration?
    
    /// Optional. The Google Cloud Storage URI to store the video output. Required for Vertex if delivery is URI.
    public var gcsUri: String?
    
    /// Creates a new `VideoResponseFormat`.
    public init(
      aspectRatio: AspectRatio? = nil,
      delivery: Delivery? = nil,
      duration: Duration? = nil,
      gcsUri: String? = nil
    ) {
      self.aspectRatio = aspectRatio
      self.delivery = delivery
      self.duration = duration
      self.gcsUri = gcsUri
    }
    enum CodingKeys: String, CodingKey {
      case aspectRatio = "aspectRatio"
      case delivery = "delivery"
      case duration = "duration"
      case gcsUri = "gcsUri"
    }
  }
}
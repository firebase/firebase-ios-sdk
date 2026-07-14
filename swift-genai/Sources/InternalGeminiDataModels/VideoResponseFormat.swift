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
  /// Configuration for video-specific output formatting.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct VideoResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The Google Cloud Storage URI to store the video output. Required for Vertex if delivery is URI.
    /// 
    /// > Important: `gcsUri` is only available in the Gemini Enterprise Agent Platform.
    package let gcsUri: String?
    
    /// Optional. Delivery mode for the generated content.
    /// 
    /// > Important: `delivery` is only available in the Gemini Enterprise Agent Platform.
    package let delivery: Delivery?
    
    /// The aspect ratio for the video output.
    /// 
    /// > Important: `aspectRatio` is only available in the Gemini Enterprise Agent Platform.
    package let aspectRatio: AspectRatio?
    
    /// Optional. The duration for the video output.
    /// 
    /// > Important: `duration` is only available in the Gemini Enterprise Agent Platform.
    package let duration: String?
    
    /// Creates a new `VideoResponseFormat`.
    package init(
      gcsUri: String? = nil,
      delivery: Delivery? = nil,
      aspectRatio: AspectRatio? = nil,
      duration: String? = nil
    ) {
      self.gcsUri = gcsUri
      self.delivery = delivery
      self.aspectRatio = aspectRatio
      self.duration = duration
    }
    enum CodingKeys: String, CodingKey {
      case gcsUri = "gcsUri"
      case delivery = "delivery"
      case aspectRatio = "aspectRatio"
      case duration = "duration"
    }
  }
}
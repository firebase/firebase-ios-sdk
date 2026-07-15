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
  /// An internal data model for `VideoResponseFormat`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1VideoResponseFormat`
  /// 
  /// Configuration for video-specific output formatting.
  package struct VideoResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. Delivery mode for the generated content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Delivery mode for the generated content.
    package let delivery: Delivery?
    
    /// Optional. The Google Cloud Storage URI to store the video output. Required for Vertex
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The Google Cloud Storage URI to store the video output. Required for Vertex
    /// if delivery is URI.
    package let gcsUri: String?
    
    /// The aspect ratio for the video output.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The aspect ratio for the video output.
    package let aspectRatio: AspectRatio?
    
    /// Optional. The duration for the video output.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The duration for the video output.
    package let duration: String?
    

    /// Creates a new `VideoResponseFormat`.
    ///
    /// - Parameters:
    ///   - delivery: Optional. Delivery mode for the generated content. (Gemini Enterprise Agent Platform only). For more details, see ``delivery``.
    ///   - gcsUri: Optional. The Google Cloud Storage URI to store the video output. Required for Vertex (Gemini Enterprise Agent Platform only). For more details, see ``gcsUri``.
    ///   - aspectRatio: The aspect ratio for the video output. (Gemini Enterprise Agent Platform only). For more details, see ``aspectRatio``.
    ///   - duration: Optional. The duration for the video output. (Gemini Enterprise Agent Platform only). For more details, see ``duration``.
    package init(
      delivery: Delivery? = nil,
      gcsUri: String? = nil,
      aspectRatio: AspectRatio? = nil,
      duration: String? = nil
    ) {
      self.delivery = delivery
      self.gcsUri = gcsUri
      self.aspectRatio = aspectRatio
      self.duration = duration
    }
    enum CodingKeys: String, CodingKey {
      case delivery = "delivery"
      case gcsUri = "gcsUri"
      case aspectRatio = "aspectRatio"
      case duration = "duration"
    }
  }
}
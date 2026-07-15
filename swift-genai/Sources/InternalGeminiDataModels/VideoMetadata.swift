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
  /// An internal data model for `VideoMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaVideoMetadata`
  /// 
  /// Deprecated: Use `GenerateContentRequest.processing_options` instead. Metadata
  /// describes the input video content.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1VideoMetadata`
  /// 
  /// Provides metadata for a video, including the start and end offsets for
  /// clipping and the frame rate.
  @available(*, deprecated)
  package struct VideoMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. The start offset of the video.
    package let startOffset: String?
    
    /// Optional. The end offset of the video.
    package let endOffset: String?
    
    /// Optional. The frame rate of the video sent to the model. If not specified, the
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The frame rate of the video sent to the model. If not specified, the
    /// default value will be 1.0.
    /// The fps range is (0.0, 24.0].
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The frame rate of the video sent to the model. If not specified,
    /// the default value is 1.0. The valid range is (0.0, 24.0].
    package let fps: Double?
    

    /// Creates a new `VideoMetadata`.
    ///
    /// - Parameters:
    ///   - startOffset: Optional. The start offset of the video.
    ///   - endOffset: Optional. The end offset of the video.
    ///   - fps: Optional. The frame rate of the video sent to the model. If not specified, the (behavior varies by backend). For more details, see ``fps``.
    package init(
      startOffset: String? = nil,
      endOffset: String? = nil,
      fps: Double? = nil
    ) {
      self.startOffset = startOffset
      self.endOffset = endOffset
      self.fps = fps
    }
    enum CodingKeys: String, CodingKey {
      case startOffset = "startOffset"
      case endOffset = "endOffset"
      case fps = "fps"
    }
  }
}
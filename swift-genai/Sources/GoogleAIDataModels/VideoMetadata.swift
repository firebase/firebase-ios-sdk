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
  /// Deprecated: Use `GenerateContentRequest.processing_options` instead. Metadata describes the input video content.
  @available(*, deprecated)
  public struct VideoMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. The end offset of the video.
    public var endOffset: Duration?
    
    /// Optional. The frame rate of the video sent to the model. If not specified, the default value will be 1.0. The fps range is (0.0, 24.0].
    public var fps: Double?
    
    /// Optional. The start offset of the video.
    public var startOffset: Duration?
    
    /// Creates a new `VideoMetadata`.
    public init(
      endOffset: Duration? = nil,
      fps: Double? = nil,
      startOffset: Duration? = nil
    ) {
      self.endOffset = endOffset
      self.fps = fps
      self.startOffset = startOffset
    }
    enum CodingKeys: String, CodingKey {
      case endOffset = "endOffset"
      case fps = "fps"
      case startOffset = "startOffset"
    }
  }
}
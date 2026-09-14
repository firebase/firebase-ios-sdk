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

/// An internal data model for `StaticMediaProcessing`.
package struct StaticMediaProcessing: Codable, Sendable, Equatable, Hashable {

  /// Optional. Segment end time. Specified as a decimal number of seconds followed
  /// by an 's' suffix, e.g., "30s". Must be non-negative and greater than
  /// `start_offset` if `start_offset` is set.
  package let endOffset: String?

  /// Optional. Video frame-rate sampling density.
  package let fps: Double?

  /// Optional. Segment start time. Specified as a decimal number of seconds followed
  /// by an 's' suffix, e.g., "10.5s". Must be non-negative.
  package let startOffset: String?

  package let type: String?

  /// Creates a new `StaticMediaProcessing`.
  ///
  /// - Parameters:
  ///   - endOffset: Optional. Segment end time. Specified as a decimal number of seconds followed
  ///   - fps: Optional. Video frame-rate sampling density.
  ///   - startOffset: Optional. Segment start time. Specified as a decimal number of seconds followed
  package init(
    endOffset: String? = nil,
    fps: Double? = nil,
    startOffset: String? = nil
  ) {
    self.endOffset = endOffset
    self.fps = fps
    self.startOffset = startOffset
    self.type = "static"
  }
  enum CodingKeys: String, CodingKey {
    case endOffset = "end_offset"
    case fps = "fps"
    case startOffset = "start_offset"
    case type = "type"
  }
}

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

/// Configuration for video output format.
package struct VideoResponseFormat: Codable, Sendable, Equatable, Hashable {

  /// The aspect ratio for the video output.
  package let aspectRatio: AspectRatio?

  /// The delivery mode for the video output.
  package let delivery: Delivery?

  /// The duration for the video output.
  package let duration: String?

  /// The video output resolution. Defaults to 720p.
  package let resolution: Resolution?

  package let type: String?

  /// Creates a new `VideoResponseFormat`.
  ///
  /// - Parameters:
  ///   - aspectRatio: The aspect ratio for the video output.
  ///   - delivery: The delivery mode for the video output.
  ///   - duration: The duration for the video output.
  ///   - resolution: The video output resolution. Defaults to 720p.
  package init(
    aspectRatio: AspectRatio? = nil,
    delivery: Delivery? = nil,
    duration: String? = nil,
    resolution: Resolution? = nil
  ) {
    self.aspectRatio = aspectRatio
    self.delivery = delivery
    self.duration = duration
    self.resolution = resolution
    self.type = "video"
  }
  enum CodingKeys: String, CodingKey {
    case aspectRatio = "aspect_ratio"
    case delivery = "delivery"
    case duration = "duration"
    case resolution = "resolution"
    case type = "type"
  }
}

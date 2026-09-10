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

package import Foundation
package import GeminiSharedDataModels

/// A video content block.
package struct VideoContent: Codable, Sendable, Equatable, Hashable {

  /// The video content.
  package let data: Data?

  /// The mime type of the video.
  package let mimeType: MimeType?

  /// A user-defined name for this content block. Can be referenced by the model
  /// in the final response.
  package let name: String?

  /// How the model processes this video for understanding.
  package let processing: JSONValue?

  /// The resolution of the media.
  package let resolution: MediaResolution?

  package let type: String?

  /// The URI of the video.
  package let uri: String?

  /// Creates a new `VideoContent`.
  ///
  /// - Parameters:
  ///   - data: The video content.
  ///   - mimeType: The mime type of the video.
  ///   - name: A user-defined name for this content block. Can be referenced by the model
  ///   - processing: How the model processes this video for understanding.
  ///   - resolution: The resolution of the media.
  ///   - uri: The URI of the video.
  package init(
    data: Data? = nil,
    mimeType: MimeType? = nil,
    name: String? = nil,
    processing: JSONValue? = nil,
    resolution: MediaResolution? = nil,
    uri: String? = nil
  ) {
    self.data = data
    self.mimeType = mimeType
    self.name = name
    self.processing = processing
    self.resolution = resolution
    self.type = "video"
    self.uri = uri
  }
  enum CodingKeys: String, CodingKey {
    case data = "data"
    case mimeType = "mime_type"
    case name = "name"
    case processing = "processing"
    case resolution = "resolution"
    case type = "type"
    case uri = "uri"
  }
}

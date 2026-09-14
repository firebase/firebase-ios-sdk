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

/// An audio content block.
package struct AudioContent: Codable, Sendable, Equatable, Hashable {

  /// The number of audio channels.
  package let channels: Int?

  /// The audio content.
  package let data: Data?

  /// The mime type of the audio.
  package let mimeType: MimeType?

  /// The sample rate of the audio.
  package let sampleRate: Int?

  package let type: String?

  /// The URI of the audio.
  package let uri: String?

  /// Creates a new `AudioContent`.
  ///
  /// - Parameters:
  ///   - channels: The number of audio channels.
  ///   - data: The audio content.
  ///   - mimeType: The mime type of the audio.
  ///   - sampleRate: The sample rate of the audio.
  ///   - uri: The URI of the audio.
  package init(
    channels: Int? = nil,
    data: Data? = nil,
    mimeType: MimeType? = nil,
    sampleRate: Int? = nil,
    uri: String? = nil
  ) {
    self.channels = channels
    self.data = data
    self.mimeType = mimeType
    self.sampleRate = sampleRate
    self.type = "audio"
    self.uri = uri
  }
  enum CodingKeys: String, CodingKey {
    case channels = "channels"
    case data = "data"
    case mimeType = "mime_type"
    case sampleRate = "sample_rate"
    case type = "type"
    case uri = "uri"
  }
}

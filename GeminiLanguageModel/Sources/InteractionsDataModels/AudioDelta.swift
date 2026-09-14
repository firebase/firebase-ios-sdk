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

/// An internal data model for `AudioDelta`.
package struct AudioDelta: Codable, Sendable, Equatable, Hashable {

  /// The number of audio channels.
  package let channels: Int?

  package let data: Data?

  package let mimeType: MimeType?

  /// Deprecated. Use sample_rate instead. The value is ignored.
  @available(*, deprecated)
  package let rate: Int?

  /// The sample rate of the audio.
  package let sampleRate: Int?

  package let type: String?

  package let uri: String?

  /// Creates a new `AudioDelta`.
  ///
  /// - Parameters:
  ///   - channels: The number of audio channels.
  ///   - data: For more details, see ``data``.
  ///   - mimeType: For more details, see ``mimeType``.
  ///   - rate: Deprecated. Use sample_rate instead. The value is ignored.
  ///   - sampleRate: The sample rate of the audio.
  ///   - uri: For more details, see ``uri``.
  package init(
    channels: Int? = nil,
    data: Data? = nil,
    mimeType: MimeType? = nil,
    rate: Int? = nil,
    sampleRate: Int? = nil,
    uri: String? = nil
  ) {
    self.channels = channels
    self.data = data
    self.mimeType = mimeType
    self.rate = rate
    self.sampleRate = sampleRate
    self.type = "audio"
    self.uri = uri
  }
  enum CodingKeys: String, CodingKey {
    case channels = "channels"
    case data = "data"
    case mimeType = "mime_type"
    case rate = "rate"
    case sampleRate = "sample_rate"
    case type = "type"
    case uri = "uri"
  }
}

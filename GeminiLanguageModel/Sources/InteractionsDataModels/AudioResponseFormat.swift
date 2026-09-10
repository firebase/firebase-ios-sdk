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

/// Configuration for audio output format.
package struct AudioResponseFormat: Codable, Sendable, Equatable, Hashable {

  /// Bit rate in bits per second (bps). Only applicable for compressed formats
  /// (MP3, Opus).
  package let bitRate: Int?

  /// The delivery mode for the audio output.
  package let delivery: Delivery?

  /// The MIME type of the audio output.
  package let mimeType: MimeType?

  /// Sample rate in Hz.
  package let sampleRate: Int?

  package let type: String?

  /// Creates a new `AudioResponseFormat`.
  ///
  /// - Parameters:
  ///   - bitRate: Bit rate in bits per second (bps). Only applicable for compressed formats
  ///   - delivery: The delivery mode for the audio output.
  ///   - mimeType: The MIME type of the audio output.
  ///   - sampleRate: Sample rate in Hz.
  package init(
    bitRate: Int? = nil,
    delivery: Delivery? = nil,
    mimeType: MimeType? = nil,
    sampleRate: Int? = nil
  ) {
    self.bitRate = bitRate
    self.delivery = delivery
    self.mimeType = mimeType
    self.sampleRate = sampleRate
    self.type = "audio"
  }
  enum CodingKeys: String, CodingKey {
    case bitRate = "bit_rate"
    case delivery = "delivery"
    case mimeType = "mime_type"
    case sampleRate = "sample_rate"
    case type = "type"
  }
}

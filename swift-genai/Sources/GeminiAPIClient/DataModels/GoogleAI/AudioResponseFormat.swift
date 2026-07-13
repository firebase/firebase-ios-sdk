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
  /// Configuration for audio output format.
  package struct AudioResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. Bit rate in bits per second (bps). Only applicable for compressed formats (MP3, Opus).
    package var bitRate: Int?
    
    /// Optional. The delivery mode for the audio output.
    package var delivery: Delivery?
    
    /// Optional. The MIME type of the audio output.
    package var mimeType: MimeType?
    
    /// Optional. Sample rate in Hz.
    package var sampleRate: Int?
    
    /// Creates a new `AudioResponseFormat`.
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
    }
    enum CodingKeys: String, CodingKey {
      case bitRate = "bitRate"
      case delivery = "delivery"
      case mimeType = "mimeType"
      case sampleRate = "sampleRate"
    }
  }
}
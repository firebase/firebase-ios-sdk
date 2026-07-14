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
  /// Configuration for audio output format.
  /// 
  /// Variant:
  /// Configuration for audio-specific output formatting.
  package struct AudioResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. Sample rate in Hz.
    /// 
    /// Variant:
    /// Optional. Sample rate for the generated audio in Hertz.
    package let sampleRate: Int?
    
    /// Optional. The MIME type of the audio output.
    package let mimeType: MimeType?
    
    /// Optional. The delivery mode for the audio output.
    /// 
    /// Variant:
    /// Optional. Delivery mode for the generated content.
    package let delivery: Delivery?
    
    /// Optional. Bit rate in bits per second (bps). Only applicable for compressed formats (MP3, Opus).
    package let bitRate: Int?
    
    /// Creates a new `AudioResponseFormat`.
    package init(
      sampleRate: Int? = nil,
      mimeType: MimeType? = nil,
      delivery: Delivery? = nil,
      bitRate: Int? = nil
    ) {
      self.sampleRate = sampleRate
      self.mimeType = mimeType
      self.delivery = delivery
      self.bitRate = bitRate
    }
    enum CodingKeys: String, CodingKey {
      case sampleRate = "sampleRate"
      case mimeType = "mimeType"
      case delivery = "delivery"
      case bitRate = "bitRate"
    }
  }
}
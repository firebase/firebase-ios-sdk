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
  /// An internal data model for `AudioResponseFormat`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaAudioResponseFormat`
  /// 
  /// Configuration for audio output format.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1AudioResponseFormat`
  /// 
  /// Configuration for audio-specific output formatting.
  package struct AudioResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The MIME type of the audio output.
    package let mimeType: MimeType?
    
    /// Optional. The delivery mode for the audio output.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The delivery mode for the audio output.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Delivery mode for the generated content.
    package let delivery: Delivery?
    
    /// Optional. Sample rate in Hz.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Sample rate in Hz.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Sample rate for the generated audio in Hertz.
    package let sampleRate: Int?
    
    /// Optional. Bit rate in bits per second (bps). Only applicable for compressed formats
    /// (MP3, Opus).
    package let bitRate: Int?
    

    /// Creates a new `AudioResponseFormat`.
    ///
    /// - Parameters:
    ///   - mimeType: Optional. The MIME type of the audio output.
    ///   - delivery: Optional. The delivery mode for the audio output. (behavior varies by backend). For more details, see ``delivery``.
    ///   - sampleRate: Optional. Sample rate in Hz. (behavior varies by backend). For more details, see ``sampleRate``.
    ///   - bitRate: Optional. Bit rate in bits per second (bps). Only applicable for compressed formats
    package init(
      mimeType: MimeType? = nil,
      delivery: Delivery? = nil,
      sampleRate: Int? = nil,
      bitRate: Int? = nil
    ) {
      self.mimeType = mimeType
      self.delivery = delivery
      self.sampleRate = sampleRate
      self.bitRate = bitRate
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case delivery = "delivery"
      case sampleRate = "sampleRate"
      case bitRate = "bitRate"
    }
  }
}
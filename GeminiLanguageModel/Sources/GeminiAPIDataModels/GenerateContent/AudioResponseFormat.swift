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

/// Configuration for audio-specific output formatting.
package struct AudioResponseFormat: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Bit rate in bits per second (bps). Only applicable for compressed formats (MP3, Opus).
  package var bitRate: Int?

  /// Delivery mode for the generated content.
  package var delivery: Delivery?

  /// The MIME type of the audio output.
  package var mimeType: MIMEType?

  /// Sample rate for the generated audio in Hertz.
  package var sampleRate: Int?

  /// Initializes a new `AudioResponseFormat`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case bitRate
    case delivery
    case mimeType
    case sampleRate
  }
}

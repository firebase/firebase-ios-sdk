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


extension AgentPlatform {
  /// The configuration for the replicated voice to use.
  package struct ReplicatedVoiceConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The mimetype of the voice sample. The only currently supported value is `audio/wav`. This represents 16-bit signed little-endian wav data, with a 24kHz sampling rate. `mime_type` will default to `audio/wav` if not set.
    package var mimeType: String?
    
    /// Optional. The sample of the custom voice.
    package var voiceSampleAudio: String?
    
    /// Creates a new `ReplicatedVoiceConfig`.
    package init(
      mimeType: String? = nil,
      voiceSampleAudio: String? = nil
    ) {
      self.mimeType = mimeType
      self.voiceSampleAudio = voiceSampleAudio
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case voiceSampleAudio = "voiceSampleAudio"
    }
  }
}
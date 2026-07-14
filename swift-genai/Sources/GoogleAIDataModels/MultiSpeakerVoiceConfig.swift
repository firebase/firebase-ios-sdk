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
  /// The configuration for the multi-speaker setup.
  public struct MultiSpeakerVoiceConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. All the enabled speaker voices.
    public var speakerVoiceConfigs: [SpeakerVoiceConfig]?
    
    /// Creates a new `MultiSpeakerVoiceConfig`.
    public init(
      speakerVoiceConfigs: [SpeakerVoiceConfig]? = nil
    ) {
      self.speakerVoiceConfigs = speakerVoiceConfigs
    }
    enum CodingKeys: String, CodingKey {
      case speakerVoiceConfigs = "speakerVoiceConfigs"
    }
  }
}
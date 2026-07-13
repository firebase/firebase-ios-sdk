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
  /// Configuration for a voice.
  package struct VoiceConfig: Codable, Sendable, Equatable, Hashable {
    /// The configuration for a prebuilt voice.
    package var prebuiltVoiceConfig: PrebuiltVoiceConfig?
    
    /// Optional. The configuration for a replicated voice. This enables users to replicate a voice from an audio sample.
    package var replicatedVoiceConfig: ReplicatedVoiceConfig?
    
    /// Creates a new `VoiceConfig`.
    package init(
      prebuiltVoiceConfig: PrebuiltVoiceConfig? = nil,
      replicatedVoiceConfig: ReplicatedVoiceConfig? = nil
    ) {
      self.prebuiltVoiceConfig = prebuiltVoiceConfig
      self.replicatedVoiceConfig = replicatedVoiceConfig
    }
    enum CodingKeys: String, CodingKey {
      case prebuiltVoiceConfig = "prebuiltVoiceConfig"
      case replicatedVoiceConfig = "replicatedVoiceConfig"
    }
  }
}
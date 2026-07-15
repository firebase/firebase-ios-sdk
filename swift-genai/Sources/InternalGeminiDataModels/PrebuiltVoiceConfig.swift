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
  /// An internal data model for `PrebuiltVoiceConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaPrebuiltVoiceConfig`
  /// 
  /// The configuration for the prebuilt speaker to use.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1PrebuiltVoiceConfig`
  /// 
  /// Configuration for a prebuilt voice.
  package struct PrebuiltVoiceConfig: Codable, Sendable, Equatable, Hashable {
    /// The name of the preset voice to use.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The name of the preset voice to use.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The name of the prebuilt voice to use.
    package let voiceName: String?
    

    /// Creates a new `PrebuiltVoiceConfig`.
    ///
    /// - Parameters:
    ///   - voiceName: The name of the preset voice to use. (behavior varies by backend). For more details, see ``voiceName``.
    package init(
      voiceName: String? = nil
    ) {
      self.voiceName = voiceName
    }
    enum CodingKeys: String, CodingKey {
      case voiceName = "voiceName"
    }
  }
}
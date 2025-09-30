// Copyright 2025 Google LLC
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

/// Configuration for the speaker to use.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
enum VoiceConfig {
  /// Configuration for the prebuilt voice to use.
  case prebuiltVoiceConfig(PrebuiltVoiceConfig)

  /// Configuration for the custom voice to use.
  case customVoiceConfig(CustomVoiceConfig)
}

/// The configuration for the prebuilt speaker to use.
///
/// Not just a string on the parent proto, because there'll likely be a lot
/// more options here.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct PrebuiltVoiceConfig: Encodable, Sendable {
  /// The name of the preset voice to use.
  let voiceName: String

  init(voiceName: String) {
    self.voiceName = voiceName
  }
}

/// The configuration for the custom voice to use.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct CustomVoiceConfig: Encodable, Sendable {
  /// The sample of the custom voice, in pcm16 s16e format.
  let customVoiceSample: Data

  init(customVoiceSample: Data) {
    self.customVoiceSample = customVoiceSample
  }
}

// MARK: - Encodable conformance

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
extension VoiceConfig: Encodable {
  enum CodingKeys: CodingKey {
    case prebuiltVoiceConfig
    case customVoiceConfig
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .prebuiltVoiceConfig(setup):
      try container.encode(setup, forKey: .prebuiltVoiceConfig)
    case let .customVoiceConfig(clientContent):
      try container.encode(clientContent, forKey: .customVoiceConfig)
    }
  }
}

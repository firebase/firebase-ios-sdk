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

/// Speech generation config.
struct ProtoSpeechConfig: Encodable, Sendable, Equatable {
  /// The configuration for the speaker to use.
  let voiceConfig: ProtoVoiceConfig?

  /// The configuration for the multi-speaker setup.
  let multiSpeakerVoiceConfig: ProtoMultiSpeakerVoiceConfig?

  /// Language code (BCP-47. e.g. en-US) for the speech synthesization.
  let languageCode: String?

  init(voiceConfig: ProtoVoiceConfig, languageCode: String?) {
    self.voiceConfig = voiceConfig
    multiSpeakerVoiceConfig = nil
    self.languageCode = languageCode
  }

  init(multiSpeakerVoiceConfig: ProtoMultiSpeakerVoiceConfig, languageCode: String?) {
    voiceConfig = nil
    self.multiSpeakerVoiceConfig = multiSpeakerVoiceConfig
    self.languageCode = languageCode
  }
}

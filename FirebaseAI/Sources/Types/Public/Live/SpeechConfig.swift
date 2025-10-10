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

/// Configuration for controlling the voice of the model during conversation.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct SpeechConfig: Sendable {
  let speechConfig: BidiSpeechConfig

  init(_ speechConfig: BidiSpeechConfig) {
    self.speechConfig = speechConfig
  }

  /// Creates a new ``SpeechConfig`` value.
  ///
  /// - Parameters:
  ///   - voiceName: The name of the prebuilt voice to be used for the model's speech response.
  ///
  ///     To learn more about the available voices, see the docs on
  ///     [Voice options](https://ai.google.dev/gemini-api/docs/speech-generation#voices)\.
  ///   - languageCode: ISO-639 language code to use when parsing text sent from the client, instead
  ///     of audio. By default, the model will attempt to detect the input language automatically.
  ///
  ///     To learn which codes are supported, see the docs on
  ///     [Supported languages](https://ai.google.dev/gemini-api/docs/speech-generation#languages)\.
  public init(voiceName: String, languageCode: String? = nil) {
    self.init(
      BidiSpeechConfig(
        voiceConfig: .prebuiltVoiceConfig(.init(voiceName: voiceName)),
        languageCode: languageCode
      )
    )
  }
}

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

/// Configuration options for audio transcriptions when communicating with a model that supports the
/// Gemini Live API.
///
/// While there are not currently any options, this will likely change in the future. For now, just
/// providing an instance of this struct will enable audio transcriptions for the corresponding
/// input or output fields.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct AudioTranscriptionConfig: Sendable {
  let audioTranscriptionConfig: BidiAudioTranscriptionConfig

  init(_ audioTranscriptionConfig: BidiAudioTranscriptionConfig) {
    self.audioTranscriptionConfig = audioTranscriptionConfig
  }

  public init() {
    self.init(BidiAudioTranscriptionConfig())
  }
}

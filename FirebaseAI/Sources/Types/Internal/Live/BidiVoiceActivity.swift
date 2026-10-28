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

/// Voice activity detected in the audio stream.
///
/// Sent by the server when automatic activity detection detects the start or end of user speech.
@available(watchOS, unavailable)
struct BidiVoiceActivity: Decodable, Sendable {
  /// The type of the VAD (voice activity detection) signal.
  let type: VoiceActivityType?

  /// The time voice activity was detected in audio time, relative to the start of the audio
  /// stream.
  let audioOffset: ProtoDuration?
}

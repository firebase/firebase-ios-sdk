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

/// Configures the realtime input behavior in `BidiGenerateContent`.
struct RealtimeInputConfig: Encodable {
  /// Configures automatic detection of activity.
  struct AutomaticActivityDetection: Encodable {
    /// If enabled, detected voice and text input count as activity. If
    /// disabled, the client must send activity signals.
    let disabled: Bool?

    /// Determines how likely speech is to be detected.
    let startOfSpeechSensitivity: StartSensitivity?

    /// Determines how likely detected speech is ended.
    let endOfSpeechSensitivity: EndSensitivity?

    /// The required duration of detected speech before start-of-speech is
    /// committed. The lower this value the more sensitive the start-of-speech
    /// detection is and the shorter speech can be recognized. However, this
    /// also increases the probability of false positives.
    let prefixPaddingMS: Int?

    /// The required duration of detected silence (or non-speech) before
    // end-of-speech is committed. The larger this value, the longer speech
    // gaps can be without interrupting the user's activity but this will
    // increase the model's latency.
    let silenceDurationMS: Int?
  }

  /// If not set, automatic activity detection is enabled by default. If
  /// automatic voice detection is disabled, the client must send activity
  /// signals.
  let automaticActivityDetection: AutomaticActivityDetection?

  /// Defines what effect activity has.
  let activityHandling: ActivityHandling?

  /// Defines which input is included in the user's turn.
  let turnCoverage: TurnCoverage?
}

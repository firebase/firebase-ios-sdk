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

/// User input that is sent in real time.
///
/// This is different from `ClientContentUpdate` in a few ways:
///
/// - Can be sent continuously without interruption to model generation.
/// - If there is a need to mix data interleaved across the
///   `ClientContentUpdate` and the `RealtimeUpdate`, server attempts to
///   optimize for best response, but there are no guarantees.
/// - End of turn is not explicitly specified, but is rather derived from user
///   activity (for example, end of speech).
/// - Even before the end of turn, the data is processed incrementally
///   to optimize for a fast start of the response from the model.
/// - Is always assumed to be the user's input (cannot be used to populate
///   conversation history).
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct BidiGenerateContentRealtimeInput: Encodable {
  /// These form the realtime audio input stream.
  let audio: InlineData?

  /// Indicates that the audio stream has ended, e.g. because the microphone was
  /// turned off.
  ///
  /// This should only be sent when automatic activity detection is enabled
  /// (which is the default).
  ///
  /// The client can reopen the stream by sending an audio message.
  let audioStreamEnd: Bool?

  /// These form the realtime video input stream.
  let video: InlineData?

  /// These form the realtime text input stream.
  let text: String?

  /// Marks the start of user activity.
  struct ActivityStart: Encodable {}

  /// Marks the start of user activity. This can only be sent if automatic
  /// (i.e. server-side) activity detection is disabled.
  let activityStart: ActivityStart?

  /// Marks the end of user activity.
  struct ActivityEnd: Encodable {}

  /// Marks the end of user activity. This can only be sent if automatic (i.e.
  /// server-side) activity detection is disabled.
  let activityEnd: ActivityEnd?

  init(audio: InlineData? = nil, video: InlineData? = nil, text: String? = nil,
       activityStart: ActivityStart? = nil, activityEnd: ActivityEnd? = nil,
       audioStreamEnd: Bool? = nil) {
    self.audio = audio
    self.video = video
    self.text = text
    self.activityStart = activityStart
    self.activityEnd = activityEnd
    self.audioStreamEnd = audioStreamEnd
  }
}

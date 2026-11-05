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

/// Represents the type of server-detected voice activity signal.
///
///  - seealso: ``LiveServerVoiceActivity``
@available(watchOS, unavailable)
public struct VoiceActivityType: DecodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case unspecified = "TYPE_UNSPECIFIED"
    case activityStart = "ACTIVITY_START"
    case activityEnd = "ACTIVITY_END"
  }

  /// Unrecognized or unspecified voice activity signal.
  public static let unknown = VoiceActivityType(kind: .unspecified)

  /// Start of user speech signal.
  public static let activityStart = VoiceActivityType(kind: .activityStart)

  /// End of user speech signal.
  public static let activityEnd = VoiceActivityType(kind: .activityEnd)

  /// The raw string representation of the `VoiceActivityType` value.
  let rawValue: String

  static let unrecognizedValueMessageCode =
    AILog.MessageCode.liveSessionUnrecognizedVoiceActivityType
}

/// Server notification indicating voice activity was detected in the input audio stream.
///
/// Voice activity is detected by the server's automatic activity detection (enabled by default,
/// see ``ActivityDetectionConfig``) when the user starts or stops speaking, and is delivered
/// through ``LiveServerContent/voiceActivity``. For example, it can be used to drive a voice
/// activity indicator, or to handle the user interrupting the model (barge-in) on the client.
@available(watchOS, unavailable)
public struct LiveServerVoiceActivity: Sendable {
  let bidiVoiceActivity: BidiVoiceActivity

  /// The type of voice activity signal (``VoiceActivityType/activityStart`` or
  /// ``VoiceActivityType/activityEnd``).
  ///
  /// This is ``VoiceActivityType/unknown`` if the server didn't specify a type, or sent a type
  /// that this version of the SDK doesn't recognize.
  public var type: VoiceActivityType {
    guard let type = bidiVoiceActivity.type,
          VoiceActivityType.Kind(rawValue: type.rawValue) != nil else {
      return .unknown
    }
    return type
  }

  /// The time voice activity was detected (in seconds), relative to the start of the audio stream.
  public var audioOffset: TimeInterval? { bidiVoiceActivity.audioOffset?.timeInterval }

  init(_ bidiVoiceActivity: BidiVoiceActivity) {
    self.bidiVoiceActivity = bidiVoiceActivity
  }
}

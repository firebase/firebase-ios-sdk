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

/// Configures the model's automatic detection of user activity.
///
/// **Public Preview**: This API is a public preview and may be subject to change.
///
///  - seealso: ``RealtimeInputConfig``
public struct ActivityDetectionConfig: Sendable {
  let bidiActivitiyDetectionConfig: BidiActivityDetectionConfig

  /// How sensitive the model interprets speech activity.
  ///
  /// **Public Preview**: This API is a public preview and may be subject to change.
  public enum Sensitivity: Sendable {
    /// The model will detect speech less often.
    ///
    /// In other words, a higher volume of speech is required for the model
    /// to consider the user is speaking.
    case low

    /// The model will detect speech more often.
    ///
    /// In other words, a lower volume of speech is required for the model
    /// to consider the user is speaking.
    case high
  }

  init(_ bidiActivityDetectionConfig: BidiActivityDetectionConfig) {
    bidiActivitiyDetectionConfig = bidiActivityDetectionConfig
  }

  /// Creates a new ``ActivityDetectionConfig`` value.
  ///
  /// - Parameters:
  ///   - startSensitivity: Determines how likely the start of speech is detected.
  ///   - endSensitivity: Determines how likely the end of speech is detected.
  ///   - prefixPadding: How long detected speech should be present before start-of-speech is
  ///     commited.
  ///
  ///     The lower this value, the more sensitive the start-of-speech detection is and the shorter
  ///     speech can be recognized. However, this also increases the probability of false positives.
  ///   - silenceDuration: How long silence (or non-speech) should be present before end-of-speech
  ///     is committed.
  ///
  ///     The larger this value, the longer speech gaps can be without interrupting the user's
  ///     activity but this will increase the model's latency.
  ///  - seealso: ``ActivityDetectionConfig/init(startSensitivity:endSensitivity:prefixPadding:silenceDuration:)-(_,_,Duration?,_)``
  ///  - seealso: ``ActivityDetectionConfig/disabled()``
  public init(startSensitivity: Sensitivity? = nil,
              endSensitivity: Sensitivity? = nil,
              prefixPadding: TimeInterval? = nil,
              silenceDuration: TimeInterval? = nil) {
    self.init(BidiActivityDetectionConfig(
      startOfSpeechSensitivity: startSensitivity
        .map(BidiActivityDetectionConfig.StartSensitivity.init),
      endOfSpeechSensitivity: endSensitivity.map(BidiActivityDetectionConfig.EndSensitivity.init),
      prefixPaddingMs: prefixPadding?.milliseconds,
      silenceDurationMs: silenceDuration?.milliseconds
    ))
  }

  /// Creates a new ``ActivityDetectionConfig`` value.
  ///
  /// This method uses `Duration` for timing related properties instead of `TimeInterval`. See the
  /// "See Also" section for
  /// the alternative initializer if you don't have access to the `Duration` API.
  ///
  /// - Parameters:
  ///   - startSensitivity: Determines how likely the start of speech is detected.
  ///   - endSensitivity: Determines how likely the end of speech is detected.
  ///   - prefixPadding: How long detected speech should be present before start-of-speech is
  ///     commited.
  ///
  ///     The lower this value, the more sensitive the start-of-speech detection is and the shorter
  ///     speech can be recognized. However, this also increases the probability of false positives.
  ///   - silenceDuration: How long silence (or non-speech) should be present before end-of-speech
  ///     is committed.
  ///
  ///     The larger this value, the longer speech gaps can be without interrupting the user's
  ///     activity but this will increase the model's latency.
  ///  - seealso: ``ActivityDetectionConfig/init(startSensitivity:endSensitivity:prefixPadding:silenceDuration:)-(_,_,TimeInterval?,_)``
  ///  - seealso: ``ActivityDetectionConfig/disabled()``
  @available(iOS 16.0, macOS 13.0, *)
  public init(startSensitivity: Sensitivity? = nil,
              endSensitivity: Sensitivity? = nil,
              prefixPadding: Duration? = nil,
              silenceDuration: Duration? = nil) {
    self.init(BidiActivityDetectionConfig(
      startOfSpeechSensitivity: startSensitivity
        .map(BidiActivityDetectionConfig.StartSensitivity.init),
      endOfSpeechSensitivity: endSensitivity.map(BidiActivityDetectionConfig.EndSensitivity.init),
      prefixPaddingMs: prefixPadding?.milliseconds,
      silenceDurationMs: silenceDuration?.milliseconds
    ))
  }

  /// Disables automatic activity detection.
  ///
  /// When automatic activity detection is enabled, the model will interpet detected voices and text
  /// as the start of activity.
  ///
  /// When automatic activity detection is disabled, the user must send activity signals manually.
  ///
  ///  - seealso: ``LiveSession/sendStartActivityRealtime()``
  ///  - seealso: ``LiveSession/sendStopActivityRealtime()``
  public static func disabled() -> Self {
    self.init(BidiActivityDetectionConfig(
      disabled: true
    ))
  }
}

private extension BidiActivityDetectionConfig.StartSensitivity {
  init(_ sensitivity: ActivityDetectionConfig.Sensitivity) {
    switch sensitivity {
    case .low: self = .low
    case .high: self = .high
    }
  }
}

private extension BidiActivityDetectionConfig.EndSensitivity {
  init(_ sensitivity: ActivityDetectionConfig.Sensitivity) {
    switch sensitivity {
    case .low: self = .low
    case .high: self = .high
    }
  }
}

private extension TimeInterval {
  var milliseconds: Int32 {
    return Int32((self * 1000).rounded())
  }
}

@available(iOS 16.0, macOS 13.0, *)
private extension Duration {
  var milliseconds: Int32 {
    return Int32(self / .milliseconds(1))
  }
}

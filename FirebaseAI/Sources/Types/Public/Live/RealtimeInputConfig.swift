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

/// Configures model input behavior when generating content in the Live API via the realtime
/// supported methods
public struct RealtimeInputConfig: Sendable {
  let bidiRealtimeInputConfig: BidiRealtimeInputConfig

  /// How a model handles user input activity.
  public enum ActivityHandling: Sendable {
    /// When the user sends input marking the start of activity, the model's current response will
    /// be cut-off immediately.
    ///
    /// The start of activity could be manually specified in the call, or the model could interpret
    /// it automatically (depending on the value of `automaticActivityDetectionConfig`).
    ///
    /// An example of activity starting implicitly could be the user speaking over the model.
    case interrupt

    /// When the user sends input marking the start of activity, the model will process it, but
    /// won't cut-off its current response.
    ///
    /// This is the inverse of `interrupt`.
    case noInterrupt
  }

  /// How the model considers which input is included in the user's turn.
  public enum TurnCoverage: Sendable {
    /// The model will exclude inactivity (e.g, silence on the audio stream) from the user's input.
    case onlyActivity

    /// The model will include all input (including inactivity) since the last turn as the user's
    /// input.
    case allInput

    /// Includes audio activity and all video since the last turn. With automatic
    /// activity detection, audio activity means speech and excludes silence.
    case audioActivityAndAllVideo
  }

  init(_ bidiRealtimeInputConfig: BidiRealtimeInputConfig) {
    self.bidiRealtimeInputConfig = bidiRealtimeInputConfig
  }

  /// Creates a new ``RealtimeInputConfig`` value.
  ///
  /// - Parameters:
  ///   - automaticActivityDetection:Configures automatic activity detection on the model.
  ///
  ///     When not set, automatic activity detection is enabled by default. If set, the user must
  ///     send activity signals.
  ///   - activityHandling: Defines how the model treats user input activity.
  ///   - turnCoverage: Defines which input is included in the user's turn, relative to the starting
  ///     and ending of the activity.
  public init(automaticActivityDetection: ActivityDetectionConfig? = nil,
              activityHandling: ActivityHandling? = nil,
              turnCoverage: TurnCoverage? = nil) {
    self.init(BidiRealtimeInputConfig(
      automaticActivityDetection: automaticActivityDetection?.bidiActivitiyDetectionConfig,
      activityHandling: activityHandling.flatMap(BidiRealtimeInputConfig.ActivityHandling.init),
      turnCoverage: turnCoverage.flatMap(BidiRealtimeInputConfig.TurnCoverage.init)
    ))
  }
}

private extension BidiRealtimeInputConfig.ActivityHandling {
  init(_ activityHandling: RealtimeInputConfig.ActivityHandling) {
    switch activityHandling {
    case .noInterrupt: self = .noInterruption
    case .interrupt: self = .startOfInterrupts
    }
  }
}

private extension BidiRealtimeInputConfig.TurnCoverage {
  init(_ turnCoverage: RealtimeInputConfig.TurnCoverage) {
    switch turnCoverage {
    case .onlyActivity: self = .onlyActivity
    case .allInput: self = .allInput
    case .audioActivityAndAllVideo: self = .audioActivityAndAllVideo
    }
  }
}

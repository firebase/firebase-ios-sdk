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

/// Configuration for controlling the proactivity of the model during conversation.
public struct LiveProactivityConfig: Sendable {
  let proactivityConfig: ProactivityConfig

  init(_ proactivityConfig: ProactivityConfig) {
    self.proactivityConfig = proactivityConfig
  }

  /// Creates a new ``LiveProactivityConfig`` value.
  ///
  /// - Parameters:
  ///   - proactiveAudio: When enabled, the model can reject responding to the last prompt. For
  /// example, this allows
  ///     the model to ignore out of context speech, or to stay silent if the user hasn't made a
  /// request yet.
  public init(proactiveAudio: Bool = false) {
    self.init(
      ProactivityConfig(proactiveAudio: proactiveAudio)
    )
  }
}

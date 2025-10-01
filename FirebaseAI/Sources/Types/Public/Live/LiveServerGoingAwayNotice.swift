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

/// Server will not be able to service client soon.
///
/// To  learn more about session limits,  see the docs on [Maximum session duration](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/multimodal-live#maximum-session-duration)\.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveServerGoingAwayNotice: Sendable {
  let goAway: GoAway
  /// The remaining time before the connection will be terminated as ABORTED.
  ///
  /// The minimal time returned here is specified differently together with
  /// the rate limits for a given model.
  public var timeLeft: TimeInterval? { goAway.timeLeft?.timeInterval }

  init(_ goAway: GoAway) {
    self.goAway = goAway
  }
}

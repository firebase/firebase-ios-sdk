// Copyright 2022 Google LLC
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

protocol SessionSamplerProtocol {
  /// Sampling rate that has to be applied across sessions.
  /// Ranges from 0 to 1 in Double.
  var sessionSamplingRate: Double { get set }

  /// Determines if a provided sessionID should be sampled or not.
  /// Note: Sample means allowed. A return of true means the event should be allowed, else dropped.
  func shouldSendEventForSession(sessionId: String) -> Bool
}

class SessionSampler: SessionSamplerProtocol {
  var sessionSamplingRate: Double

  /// TODO: Update this to a sampling logic once we have the configuration flags in place.
  /// Currently defaulted to 1.0 where no events are dropped.
  init(sessionSamplingRate: Double = 1.0) {
    self.sessionSamplingRate = sessionSamplingRate
  }

  func shouldSendEventForSession(sessionId: String) -> Bool {
    let randomFloat = Double.random(in: 0 ..< 1)
    if randomFloat > sessionSamplingRate {
      return false
    }
    return true
  }
}

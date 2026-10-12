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

struct BidiRealtimeInputConfig: Encodable, Sendable {
  enum TurnCoverage: String, Encodable {
    case unspecified = "TURN_COVERAGE_UNSPECIFIED"
    case onlyActivity = "TURN_INCLUDES_ONLY_ACTIVITY"
    case allInput = "TURN_INCLUDES_ALL_INPUT"
    case audioActivityAndAllVideo = "TURN_INCLUDES_AUDIO_ACTIVITY_AND_ALL_VIDEO"
  }

  enum ActivityHandling: String, Encodable {
    case unspecified = "ACTIVITY_HANDLING_UNSPECIFIED"
    case startOfInterrupts = "START_OF_ACTIVITY_INTERRUPTS"
    case noInterruption = "NO_INTERRUPTION"
  }

  let automaticActivityDetection: BidiActivityDetectionConfig?
  let activityHandling: ActivityHandling?
  let turnCoverage: TurnCoverage?

  init(automaticActivityDetection: BidiActivityDetectionConfig? = nil,
       activityHandling: ActivityHandling? = nil, turnCoverage: TurnCoverage? = nil) {
    self.automaticActivityDetection = automaticActivityDetection
    self.activityHandling = activityHandling
    self.turnCoverage = turnCoverage
  }
}

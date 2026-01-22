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

/// An enumeration of time periods.
enum TimePeriod: Int, CaseIterable, Codable {
  case daily = 1

  var timeInterval: TimeInterval {
    Double(rawValue) * 86400
  }
}

/// A structure representing SDK usage.
struct Heartbeat: Codable, Equatable {
  private static let version: Int = 0

  let agent: String
  let date: Date
  let version: Int
  let timePeriods: [TimePeriod]

  init(agent: String,
       date: Date,
       timePeriods: [TimePeriod] = [],
       version: Int = version) {
    self.agent = agent
    self.date = date
    self.timePeriods = timePeriods
    self.version = version
  }
}

extension Heartbeat: HeartbeatsPayloadConvertible {
  func makeHeartbeatsPayload() -> HeartbeatsPayload {
    let userAgentPayloads = [
      HeartbeatsPayload.UserAgentPayload(agent: agent, dates: [date]),
    ]
    return HeartbeatsPayload(userAgentPayloads: userAgentPayloads)
  }
}

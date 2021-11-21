// Copyright 2021 Google LLC
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
  /// The raw value is the number of calendar days within each time period.
  // TODO: Enable disabled types in future iterations.
  case daily = 1 // , weekly = 7, monthly = 28

  /// The number of seconds in a given time period.
  var timeInterval: TimeInterval {
    Double(rawValue) * 86400 /* seconds in day */
  }

  /// All enumerated time periods.
  static var periods: AllCases { Self.allCases }
}

/// A structure representing SDK usage.
struct Heartbeat: Codable, Equatable {
  /// The version of the model. Used for decoding/encoding. Manually incremented when model changes.
  private static let version: Int = 0

  /// An anonymous piece of information (i.e. user agent) to associate the heartbeat with.
  let agent: String

  /// The date when the heartbeat was recorded (standardized to be the start of a calendar day).
  let date: Date

  /// The heartbeat's model version.
  let version: Int

  /// An array of `TimePeriod`s that the heartbeat is tagged with. See `TimePeriod`.
  ///
  /// Heartbeats represent anonymous data points that measure SDK usage in moving averages for
  /// various time periods. Because a single heartbeat can help calculate moving averages for multiple
  /// time periods, this property serves to capture all the time periods that the heartbeat can represent in
  /// a moving average.
  let timePeriods: [TimePeriod]

  /// Intializes a `Heartbeat` with given `info` and, optionally, a `date` and `version`.
  /// - Parameters:
  ///   - agent: An anonymous piece of information to associate the heartbeat with.
  ///   - date: The date when the heartbeat was recorded. Defaults to the current date.
  ///   - version: The heartbeat's model version. Defaults to the current model version.
  init(agent: String,
       date: Date,
       timePeriods: [TimePeriod],
       version: Int = version) {
    self.agent = agent
    self.date = date
    self.timePeriods = timePeriods
    self.version = version
  }
}
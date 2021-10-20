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
  // TODO: Enable disabled types in future iterations.
  // The raw value is the number of calendar days within each time period.
  case daily = 1 // , case weekly = 7, monthly = 28

  /// The number of seconds in a given time period.
  var timeInterval: TimeInterval { Double(rawValue) * 86400 /* seconds in day */ }

  /// All enumerated time periods.
  static var periods: AllCases { Self.allCases }
}

/// A structure representing SDK usage.
struct Heartbeat: Codable, Equatable {
  private static let version: Int = 0

  /// <#Description#>
  let info: String
  /// <#Description#>
  let date: Date
  /// <#Description#>
  let version: Int

  /// <#Description#>
  var timePeriods: [TimePeriod] = []

  init(info: String,
       date: Date = .init(),
       version: Int = Self.version) {
    self.info = info
    // A heartbeat's date is a calendar day standardized at the start of day.
    self.date = Calendar(identifier: .gregorian).startOfDay(for: date)
    self.version = version
  }
}

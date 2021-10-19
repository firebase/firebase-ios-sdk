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

/// <#Description#>
enum TimePeriod: TimeInterval, CaseIterable, Codable {
  // TODO: Enable disabled types in future iterations.
  case daily = 1 // , case weekly = 7, monthly = 28

  /// <#Description#>
  var timeInterval: RawValue { rawValue * 86400 /* seconds in a day */ }

  /// <#Description#>
  static var periods: AllCases { Self.allCases }
}

/// <#Description#>
struct Heartbeat: Codable, Equatable {
  private static let version: Int = 0

  let info: String
  let date: Date
  let version: Int

  var timePeriods: [TimePeriod] = []

  init(info: String,
       date: Date = .init(),
       version: Int = Self.version) {
    self.info = info
    // A heartbeat's date is a caledar day standardized at the start of a day.
    self.date = Calendar(identifier: .gregorian).startOfDay(for: date)
    self.version = version
  }
}

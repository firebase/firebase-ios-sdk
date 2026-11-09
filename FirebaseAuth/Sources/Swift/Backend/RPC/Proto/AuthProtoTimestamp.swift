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

/// Decodes the timestamps in backend responses, like the `finalizeEnrollmentTime` of a TOTP
/// enrollment.
///
/// The backend sends a timestamp as an RFC 3339 string, such as `2026-11-09T14:40:00.123Z`. The
/// fractional seconds are optional. `DateFormatter` keeps milliseconds and drops any further
/// digits.
enum AuthProtoTimestamp {
  /// Returns the date of an RFC 3339 timestamp from a backend response.
  ///
  /// The date doesn't depend on the device's locale or calendar.
  /// - Parameter value: The timestamp field of the response.
  /// - Returns: The date, or `nil` if the value is missing, isn't a string, or isn't an RFC 3339
  ///   timestamp.
  static func date(from value: AnyHashable?) -> Date? {
    guard let timestamp = value as? String else {
      return nil
    }
    // The POSIX locale also selects the Gregorian calendar, so the year doesn't depend on the
    // device's settings.
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    if let date = dateFormatter.date(from: timestamp) {
      return date
    }
    // RFC 3339 timestamps may omit the fractional seconds.
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return dateFormatter.date(from: timestamp)
  }
}

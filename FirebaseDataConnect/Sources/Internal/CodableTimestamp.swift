// Copyright 2024 Google LLC
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

import FirebaseCore
import FirebaseSharedSwift

/**
 * A protocol describing the encodable properties of a Timestamp.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the Timestamp class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableTimestamp: Codable {
  var seconds: Int64 { get }
  var nanoseconds: Int32 { get }

  init(seconds: Int64, nanoseconds: Int32)
}

/** The keys in a Timestamp. Must match the properties of CodableTimestamp. */
private enum TimestampKeys: String, CodingKey {
  case seconds
  case nanoseconds
}

/**
 * An extension of Timestamp that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension CodableTimestamp {
  // TODO: move to static
  var regex: NSRegularExpression {
    let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{0,9})?(Z|[+-]\d{2}:\d{2})$"#
    return try! NSRegularExpression(pattern: pattern)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let timestampString = try container.decode(String.self)

    guard CodableTimestampHelper.regex
      .firstMatch(in: timestampString, range: NSRange(location: 0,
                                                      length: timestampString.count)) !=
      nil else {
      FirebaseLogger.dataConnect
        .error(
          "Timestamp string: \(timestampString) does not conform to the RFC3339 specification."
        )
      throw DataConnectError.invalidTimestampFormat
    }

    // Define the character set of separators
    let separators = CharacterSet(charactersIn: ".zZ+-")

    // Split the string using the character set
    let components = timestampString.components(separatedBy: separators)

    var sec = CodableTimestampHelper.convertSeconds(from: components[0])

    if components.count == 3 {
      let diffSign = timestampString.contains("+") ? 1 : -1
      let parts = components[2].split(separator: ":")
      let hours = Int(parts[0])!
      let minutes = Int(parts[1])!
      let timeZoneDiffer = hours * 3600 + minutes * 60
      sec += Int64(timeZoneDiffer * diffSign)
    }

    let nanoSecondString = timestampString.contains(".") ?
      components[1].padding(toLength: 9, withPad: "0", startingAt: components[1].count)
      : "0"
    let nanoSecond = Int32(nanoSecondString)!
    self.init(seconds: sec, nanoseconds: nanoSecond)
  }

  public func encode(to encoder: any Encoder) throws {
    // timestamp to string
    var container = encoder.singleValueContainer()
    let date = Date(timeIntervalSince1970: Double(self.seconds))
    let seconds = CodableTimestampHelper.formatter.string(from: date)
    let nanoSeconds = nanoseconds == 0 ? "" : "." + String(nanoseconds)
      .padding(toLength: 9, withPad: "0", startingAt: 0)
    try container.encode("\(seconds)\(nanoSeconds)Z")
  }
}

/** Extends Timestamp to conform to Codable. */
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Timestamp: CodableTimestamp {}

class CodableTimestampHelper {
  static let regex =
    try! NSRegularExpression(
      pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{0,9})?(Z|[+-]\d{2}:\d{2})$"#
    )

  static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
  }()

  static func convertSeconds(from secondString: String) -> Int64 {
    let date: Date = formatter.date(from: secondString)!

    let timeInterval = date.timeIntervalSince1970

    return Int64(timeInterval)
  }
}

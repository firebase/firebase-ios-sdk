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
import SwiftProtobuf

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
  public init(from decoder: any Swift.Decoder) throws {
    let container = try decoder.singleValueContainer()
    let timestampString = try container.decode(String.self).uppercased()

    guard CodableTimestampHelper.regex
      .firstMatch(in: timestampString, range: NSRange(location: 0,
                                                      length: timestampString.count)) !=
      nil else {
      FirebaseLogger.dataConnect
        .error(
          "Timestamp string: \(timestampString) format doesn't support."
        )
      throw DataConnectError.invalidTimestampFormat
    }

    let buf: Google_Protobuf_Timestamp =
      try! Google_Protobuf_Timestamp(jsonString: "\"\(timestampString)\"")
    self.init(seconds: buf.seconds, nanoseconds: buf.nanos)
  }

  public func encode(to encoder: any Swift.Encoder) throws {
    // timestamp to string
    var container = encoder.singleValueContainer()
    let bufString = try! Google_Protobuf_Timestamp(seconds: seconds, nanos: nanoseconds)
      .jsonString()
    let timestampString = bufString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    try container.encode(timestampString)
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
}
